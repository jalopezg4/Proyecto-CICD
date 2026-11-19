# Terraform de Gastico (paso 8 del plan)

Un solo root module (`infra/`), con un workspace de Terraform por ambiente (`staging` y
`production`): mismo código, mismo digest de imagen promovido entre los dos, estados separados
en el mismo bucket S3.

## Arquitectura

Ver la sección 3 del plan (`plan-proyecto-final.md`). Resumen de los módulos:

| Módulo | Qué crea |
|---|---|
| `network` | VPC por defecto (no se crea una propia), security groups de mínimo privilegio, y el endpoint Gateway de S3 (gratis) |
| `ecr` | Repositorios `gastico-backend` / `gastico-frontend`, escaneo al subir, tags inmutables. **Compartidos** entre staging y producción (D5) |
| `ssm` | `/gastico/<env>/current`, `/gastico/<env>/last-good` (D7) y el secreto de NiceGUI (`storage-secret`, `SecureString`, generado por Terraform) |
| `alb` | Genérico: se instancia dos veces. Público (frontend, sticky sessions, `/health/live`) e interno (backend, D3) |
| `ecs-service` | Una tarea Fargate genérica; se instancia dos veces (backend y frontend) desde `main.tf` |
| `monitoring` | Dashboard de CloudWatch del ambiente (peticiones, errores, latencia, tareas sanas, CPU/memoria, alarmas y errores recientes en los logs) y 6 alarmas: 5xx, latencia p95 > 1.5 s, frontend/backend sin tareas sanas, CPU > 80 %. Sin acciones (no hay SNS): se ven en la consola y en el resumen de cada run del CD |

Decisiones no obvias:

- **No hay Service Connect ni Cloud Map.** El plan original (D3) decía "backend alcanzable solo
  por ECS Service Connect", pero **el Learner Lab bloquea todo el servicio `servicediscovery`**
  (se probó a mano con el CLI tanto el namespace HTTP de Service Connect como el DNS namespace
  clásico de Cloud Map: los dos dan `AccessDeniedException`). En su lugar, el backend va detrás
  de un **segundo ALB, interno** (`module.alb_backend`, sin salida a internet): la intención de
  D3 se mantiene (el backend sigue sin ser alcanzable fuera de la VPC ni directamente desde el
  frontend sin pasar por el ALB), pero el mecanismo es otro. `GASTICO_API_URL` del frontend
  apunta al DNS de ese ALB interno, no a un nombre resuelto por Cloud Map.
- **Recursos compartidos (ECR, VPC endpoint de S3):** staging los crea; producción los reutiliza
  (variable `gestiona_recursos_compartidos` en `main.tf`, basada en `terraform.workspace`). Por
  eso **hay que aplicar `staging` antes que `production`** la primera vez.
- **Backend con IP pública, pero igual inalcanzable desde fuera (D3).** Nadie puede *iniciar*
  una conexión hacia el backend salvo el ALB interno (lo bloquea su security group); la IP
  pública es solo para que la tarea pueda bajar su propia imagen de ECR y mandar logs a
  CloudWatch, sin pagar VPC endpoints de interfaz. **Antes se usaban VPC endpoints** (sin IP
  pública), pero se quitaron en la revisión del PR #8 por dos razones:
  1. Solo puede haber un endpoint con `private_dns_enabled = true` por servicio y por VPC: el
     de staging bloqueaba a producción (`terraform apply` fallaba con "conflicting DNS domain").
  2. El DNS privado de un endpoint de interfaz aplica a **toda la VPC**, no solo a las subredes
     del backend: el frontend también terminaba resolviendo ECR hacia el endpoint del *otro*
     ambiente y se quedaba sin poder bajar su imagen (timeout silencioso).
  Quitarlos también bajó el costo: ~USD 0.12/h por ambiente (3 endpoints × 2 AZ × USD 0.01/h).
  El endpoint Gateway de S3 (gratis, no tiene este problema) se queda.
- **`description` de un `aws_security_group` fuerza reemplazo.** Cambiarlo (aunque sea solo el
  texto) hace que Terraform destruya y recree el SG completo. Si otro SG lo referencia por ID en
  una regla, hay que romper esa referencia a mano primero (o con un `apply` previo) o el
  `destroy` se queda colgado con `DependencyViolation`.
- **`GASTICO_STORAGE_SECRET` nunca es una variable de Terraform ni de CI:** se genera con
  `random_password`, se guarda en SSM como `SecureString`, y el contenedor lo recibe por
  `secrets` (valueFrom) en la task definition, no por una variable de entorno en texto plano.
- **Rol de IAM:** solo existe `LabRole` (restricción del Learner Lab). No se crean roles propios;
  `data "aws_iam_role" "lab"` lo busca por nombre.

## 1. Bootstrap (una sola vez, con una sesión de Learner Lab activa)

El bucket del backend no lo crea Terraform (necesita existir antes de poder guardarle el estado).

```bash
aws sts get-caller-identity   # confirma que la sesión del lab está activa
CUENTA=$(aws sts get-caller-identity --query Account --output text)
BUCKET="gastico-tfstate-${CUENTA}"

aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

El bucket depende de qué cuenta de Learner Lab despliega (los secrets de AWS del CD tienen que
ser de esa misma cuenta), así que nunca se escribe en `backend.hcl`: siempre se pasa con
`-backend-config` al hacer `init`, tanto a mano como desde el CD (paso 9).

## 2. Primer `apply` de staging

```bash
cd infra
terraform init -backend-config=backend.hcl -backend-config="bucket=$BUCKET"
terraform workspace new staging
terraform workspace new production   # lo dejamos creado, no hace falta seleccionarlo todavía
terraform workspace select staging

terraform apply \
  -var="backend_image_tag=<tag-que-ya-existe-en-ecr>" \
  -var="frontend_image_tag=<tag-que-ya-existe-en-ecr>" \
  -var="app_version=<mismo-tag>"
```

La primera vez, `backend_image_tag`/`frontend_image_tag` no pueden referenciar una imagen que
todavía no existe en ECR (el repo lo crea este mismo `apply`): hay que subir al menos una imagen
de cada servicio antes (o en dos pasos: `apply` solo de `module.ecr_*`, build+push, y luego el
`apply` completo).

## 3. `apply` de producción

```bash
terraform workspace select production
terraform apply \
  -var="backend_image_tag=vX.Y.Z" \
  -var="frontend_image_tag=vX.Y.Z" \
  -var="app_version=vX.Y.Z"
```

## 4. Rollback (D9: el rollback es un deploy más)

Volver a aplicar con el tag de `last-good`:

```bash
TAG=$(aws ssm get-parameter --name /gastico/staging/last-good --query Parameter.Value --output text)
terraform apply -var="backend_image_tag=$TAG" -var="frontend_image_tag=$TAG" -var="app_version=$TAG"
```

## 5. Destruir todo (al terminar la demo)

```bash
terraform workspace select production && terraform destroy
terraform workspace select staging && terraform destroy
```
