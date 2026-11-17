# D1/restricción del Learner Lab: no se crea una VPC propia, se usa la VPC por defecto.
data "aws_vpc" "default" {
  default = true
}

data "aws_region" "current" {}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_route_tables" "default" {
  vpc_id = data.aws_vpc.default.id
}

locals {
  # Reparte las subredes de la VPC por defecto entre los dos ambientes: así cada uno queda en
  # AZs distintas y los VPC endpoints de interfaz (que son 1 por subred) no compiten entre
  # workspaces. Hacen falta al menos 4 subredes en la VPC por defecto (2 por ambiente).
  subredes_ordenadas = sort(data.aws_subnets.default.ids)
  offset             = var.environment == "staging" ? 0 : 2
  subnet_ids         = slice(local.subredes_ordenadas, local.offset, local.offset + 2)
}

check "suficientes_subredes" {
  assert {
    condition     = length(local.subredes_ordenadas) >= 4
    error_message = "La VPC por defecto necesita al menos 4 subredes (2 por ambiente); tiene ${length(local.subredes_ordenadas)}."
  }
}

# ---------------------------------------------------------------------------
# Security groups (mínimo privilegio: cada capa solo recibe de la anterior)
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB publico de ${var.name}: solo HTTP desde internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Hacia el frontend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb" }
}

# D3: el frontend recibe público, pero el navegador nunca llega directo a él: solo entra
# tráfico del ALB. Tiene IP pública solo para poder bajar su imagen de ECR (egress), no
# para recibir tráfico directo (eso lo bloquea el ingress de abajo).
resource "aws_security_group" "frontend" {
  name        = "${var.name}-frontend"
  description = "Frontend de ${var.name}: solo recibe trafico del ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Desde el ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "ECR, CloudWatch y el backend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-frontend" }
}

# El Learner Lab bloquea todo el servicio "servicediscovery" (ni namespace HTTP de Service
# Connect ni el DNS de Cloud Map clásico: se probaron los dos a mano con el CLI y los dos dan
# AccessDeniedException). Sin eso, el frontend no puede resolver "backend" por nombre, así que
# en su lugar hay un segundo ALB, interno (sin salida a internet, D3 se mantiene en espíritu:
# el backend sigue sin ser alcanzable desde fuera de la VPC, nada más que no es Service Connect).
resource "aws_security_group" "alb_backend" {
  name        = "${var.name}-alb-backend"
  description = "ALB interno frente al backend: solo recibe del frontend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Desde el frontend"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Hacia el backend"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb-backend" }
}

# D3: backend privado, sin IP pública. Solo lo alcanza el ALB interno (que a su vez solo
# recibe del frontend).
resource "aws_security_group" "backend" {
  name        = "${var.name}-backend"
  description = "Backend de ${var.name}: privado, solo trafico del ALB interno"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Desde el ALB interno"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_backend.id]
  }

  egress {
    # Sin IP pública no hay ruta a internet (ni la habrá, aunque el SG lo permita): solo
    # llega a los VPC endpoints de abajo, que son los únicos destinos realmente alcanzables.
    description = "Hacia los VPC endpoints (ECR, CloudWatch)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-backend" }
}

# ---------------------------------------------------------------------------
# VPC endpoints: el backend no tiene IP pública, así que no puede salir por el Internet
# Gateway. Sin esto no podría bajar su imagen de ECR ni mandar logs a CloudWatch.
# ---------------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpce"
  description = "Endpoints de interfaz (ECR, CloudWatch Logs) para el backend privado"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTPS desde el backend"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # Un VPC endpoint de interfaz con DNS privado activado reemplaza la resolución de
  # "api/dkr.ecr...amazonaws.com" para TODA la VPC (no solo para las subredes del backend):
  # no se puede limitar por subred. Sin esto, el frontend (que sí sale a internet) también
  # intenta resolver ECR hacia este endpoint y el SG lo bloquea en silencio (timeout, no rechazo).
  ingress {
    description     = "HTTPS desde el frontend (el DNS privado del endpoint aplica a toda la VPC)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-vpce" }
}

# Interfaz: están en las 2 subredes de este ambiente, así que no compiten con las del otro.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-ecr-api" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-ecr-dkr" }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-logs" }
}

# Gateway: se asocia a tablas de rutas (no a subredes). Si staging y producción comparten
# tabla de rutas, solo uno de los dos la crea (ver variable crear_s3_endpoint_compartido);
# el otro la reutiliza sin declarar nada (ECR consulta S3 por debajo para las capas de imagen).
resource "aws_vpc_endpoint" "s3" {
  count             = var.crear_s3_endpoint_compartido ? 1 : 0
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids
  tags              = { Name = "gastico-s3-compartido" }
}
