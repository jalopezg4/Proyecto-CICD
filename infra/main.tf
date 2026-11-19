locals {
  # terraform.workspace vale "default" si nadie seleccionó "staging"/"production" (ver
  # infra/README.md): seleccionar el workspace es responsabilidad de quien aplica, no se valida
  # aquí, porque "terraform validate" evalúa esto sin workspace seleccionado (rompería el CI en
  # cada PR, incluso sin tocar infra/).
  environment = terraform.workspace
  name        = "${var.project}-${local.environment}"

  # El primer ambiente que se aplica (staging, por convención) crea los recursos que se
  # comparten entre los dos workspaces porque viven en la misma VPC por defecto: los
  # repositorios de ECR (D5: misma imagen por digest en los dos ambientes) y el VPC
  # endpoint de S3 (un endpoint Gateway se asocia a tablas de rutas, y staging/producción
  # suelen compartir la tabla de rutas principal). Producción los reutiliza.
  gestiona_recursos_compartidos = local.environment == "staging"
}

# Restricción del Learner Lab: no se pueden crear roles IAM propios, solo existe LabRole.
data "aws_iam_role" "lab" {
  name = "LabRole"
}

module "network" {
  source                       = "./modules/network"
  name                         = local.name
  crear_s3_endpoint_compartido = local.gestiona_recursos_compartidos
}

module "ecr_backend" {
  source = "./modules/ecr"
  name   = "gastico-backend"
  manage = local.gestiona_recursos_compartidos
}

module "ecr_frontend" {
  source = "./modules/ecr"
  name   = "gastico-frontend"
  manage = local.gestiona_recursos_compartidos
}

module "ssm" {
  source      = "./modules/ssm"
  project     = var.project
  environment = local.environment
}

module "alb" {
  source            = "./modules/alb"
  name              = local.name
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.alb_security_group_id
  target_port       = 8080
  listener_port     = 80 # público: el navegador entra por 80, el contenedor escucha en 8080
  health_check_path = "/health/live"
}

# ALB interno frente al backend: reemplaza a Service Connect/Cloud Map, que el Learner Lab
# bloquea por completo (ver el comentario en modules/network/main.tf). Sin salida a internet
# (internal = true): sigue sin ser alcanzable fuera de la VPC, la intención de D3 se mantiene.
module "alb_backend" {
  source            = "./modules/alb"
  name              = "${local.name}-backend"
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.alb_backend_security_group_id
  target_port       = 8000
  internal          = true
  health_check_path = "/health"
  sticky_sessions   = false
}

resource "aws_ecs_cluster" "este" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "disabled" # tiene costo adicional; no hace falta para el alcance del curso
  }
}

module "backend" {
  source             = "./modules/ecs-service"
  name               = "${local.name}-backend"
  cluster_arn        = aws_ecs_cluster.este.arn
  image              = "${module.ecr_backend.repository_url}:${var.backend_image_tag}"
  container_port     = 8000
  execution_role_arn = data.aws_iam_role.lab.arn
  task_role_arn      = data.aws_iam_role.lab.arn
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.network.backend_security_group_id
  # D3: nadie puede iniciar una conexión hacia el backend salvo el ALB interno (lo bloquea su
  # SG); la IP pública es solo para que pueda bajar su imagen de ECR y mandar logs sin pagar
  # VPC endpoints de interfaz (ver revisión del PR #8).
  assign_public_ip = true
  target_group_arn = module.alb_backend.target_group_arn

  environment_variables = {
    APP_ENV     = local.environment
    APP_VERSION = var.app_version
  }
}

module "frontend" {
  source         = "./modules/ecs-service"
  name           = "${local.name}-frontend"
  cluster_arn    = aws_ecs_cluster.este.arn
  image          = "${module.ecr_frontend.repository_url}:${var.frontend_image_tag}"
  container_port = 8080
  # La prueba de carga del paso 6 mostró que la página del frontend es lo más pesado.
  cpu                = 512
  memory             = 1024
  execution_role_arn = data.aws_iam_role.lab.arn
  task_role_arn      = data.aws_iam_role.lab.arn
  subnet_ids         = module.network.subnet_ids
  security_group_id  = module.network.frontend_security_group_id
  assign_public_ip   = true # necesita salir a internet para bajar su imagen de ECR
  target_group_arn   = module.alb.target_group_arn

  environment_variables = {
    GASTICO_API_URL    = "http://${module.alb_backend.dns_name}:8000"
    GASTICO_FRONT_PORT = "8080"
    APP_ENV            = local.environment
    APP_VERSION        = var.app_version
  }

  secrets = {
    GASTICO_STORAGE_SECRET = module.ssm.storage_secret_arn
  }

  depends_on = [module.backend]
}

# Dashboard y alarmas de CloudWatch del ambiente (ver modules/monitoring)
module "monitoring" {
  source                           = "./modules/monitoring"
  name                             = local.name
  environment                      = local.environment
  region                           = var.aws_region
  cluster_name                     = aws_ecs_cluster.este.name
  alb_arn_suffix                   = module.alb.arn_suffix
  frontend_target_group_arn_suffix = module.alb.target_group_arn_suffix
  backend_alb_arn_suffix           = module.alb_backend.arn_suffix
  backend_target_group_arn_suffix  = module.alb_backend.target_group_arn_suffix
  frontend_service_name            = module.frontend.service_name
  backend_service_name             = module.backend.service_name
  log_group_names                  = [module.frontend.log_group_name, module.backend.log_group_name]
}
