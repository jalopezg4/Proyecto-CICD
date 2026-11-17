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
  # Las dos ambientes comparten todas las subredes de la VPC por defecto: ya no hay VPC
  # endpoints de interfaz (1 por subred) que puedan competir entre workspaces, así que no hace
  # falta repartirlas (ver infra/README.md, revisión del PR #8).
  subnet_ids = data.aws_subnets.default.ids
}

check "suficientes_subredes" {
  assert {
    # El ALB necesita al menos 2 subredes en AZs distintas.
    condition     = length(local.subnet_ids) >= 2
    error_message = "La VPC por defecto necesita al menos 2 subredes; tiene ${length(local.subnet_ids)}."
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

# D3: el backend no es alcanzable desde fuera de la VPC (ni directamente desde el frontend):
# solo recibe del ALB interno. Tiene IP pública solo para egress (bajar su imagen de ECR,
# mandar logs a CloudWatch); nadie puede iniciar una conexión hacia él salvo el ALB interno.
# Antes esto se resolvía con VPC endpoints de interfaz, pero costaban ~USD 0.12/h por ambiente
# y además con private_dns_enabled=true (necesario para que ECS los use al resolver ECR)
# afectan a TODA la VPC: producción no podía crear los suyos propios (ya existían los de
# staging) y de paso el frontend también intentaba resolver hacia ellos y se quedaba sin
# acceso. Ver la revisión del PR #8.
resource "aws_security_group" "backend" {
  name        = "${var.name}-backend"
  description = "Backend de ${var.name}: solo recibe trafico del ALB interno"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Desde el ALB interno"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_backend.id]
  }

  egress {
    description = "ECR y CloudWatch"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-backend" }
}

# Gateway: gratis, y evita que el tráfico de S3 (las capas de imagen de ECR viven ahí) salga
# por el Internet Gateway. Se asocia a tablas de rutas (no a subredes): si staging y producción
# comparten tabla de rutas, solo uno de los dos la crea (ver variable crear_s3_endpoint_compartido);
# el otro la reutiliza sin declarar nada.
resource "aws_vpc_endpoint" "s3" {
  count             = var.crear_s3_endpoint_compartido ? 1 : 0
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default.ids
  tags              = { Name = "gastico-s3-compartido" }
}
