# Terraform de Gastico (paso 8 del plan)

Un solo root module (`infra/`), con un workspace de Terraform por ambiente (`staging` y
`production`): mismo código, mismo digest de imagen promovido entre los dos, estados separados
en el mismo bucket S3.

## Arquitectura

Ver la sección 3 del plan (`plan-proyecto-final.md`). Resumen de los módulos:

| Módulo | Qué crea |
|---|---|
| `network` | VPC por defecto (no se crea una propia), security groups de mínimo privilegio, y los VPC endpoints que necesita el backend sin IP pública (ECR, CloudWatch, S3) |
| `ecr` | Repositorios `gastico-backend` / `gastico-frontend`, escaneo al subir, tags inmutables. **Compartidos** entre staging y producción (D5) |
| `ssm` | `/gastico/<env>/current`, `/gastico/<env>/last-good` (D7) y el secreto de NiceGUI (`storage-secret`, `SecureString`, generado por Terraform) |
| `alb` | Genérico: se instancia dos veces. Público (frontend, sticky sessions, `/health/live`) e interno (backend, D3) |
| `ecs-service` | Una tarea Fargate genérica; se instancia dos veces (backend y frontend) desde `main.tf` |

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
- **Subredes repartidas por ambiente:** cada ambiente usa 2 subredes distintas de la VPC por
  defecto (`modules/network/main.tf`), para que los VPC endpoints de interfaz (1 por subred) de
  un workspace no choquen con los del otro.
- **Backend sin IP pública (D3):** no tiene ruta a internet, así que necesita VPC endpoints para
  bajar su imagen de ECR y mandar logs. El frontend sí tiene IP pública (solo para esto: el
  security group igual le bloquea cualquier tráfico que no venga del ALB público).
- **El SG de los VPC endpoints permite tanto al backend como al frontend.** Un VPC endpoint de
  interfaz con DNS privado activado (`private_dns_enabled = true`) reemplaza la resolución del
  nombre público (p. ej. `api.ecr.us-east-1.amazonaws.com`) para **toda la VPC**, no solo para
  las subredes del backend: no se puede limitar por subred. Si el SG solo deja pasar al backend,
  el frontend (que también resuelve ese nombre hacia el endpoint) se queda sin poder bajar su
  propia imagen ni mandar logs, y falla con un timeout silencioso, no con un error claro.
- **`description` de un `aws_security_group` fuerza reemplazo.** Cambiarlo (aunque sea solo el
  texto) hace que Terraform destruya y recree el SG completo. Si otro SG lo referencia por ID en
  una regla (como el de los VPC endpoints), hay que romper esa referencia a mano primero (o con
  un `apply` previo) o el `destroy` se queda colgado con `DependencyViolation`.
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

Reemplazar `<BUCKET>` en `infra/backend.hcl` por ese nombre (o pasarlo con
`-backend-config="bucket=$BUCKET"` en el `init`, sin tocar el archivo).

## 2. Primer `apply` de staging

```bash
cd infra
terraform init -backend-config=backend.hcl
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
