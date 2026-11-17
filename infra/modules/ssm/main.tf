# D7: fuente de verdad para el rollback. El pipeline actualiza el valor en cada deploy
# (terraform apply con un value de referencia no debe pelearse con eso).
resource "aws_ssm_parameter" "current" {
  name      = "/${var.project}/${var.environment}/current"
  type      = "String"
  value     = "sin-desplegar"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "last_good" {
  name      = "/${var.project}/${var.environment}/last-good"
  type      = "String"
  value     = "sin-desplegar"
  overwrite = true

  lifecycle {
    ignore_changes = [value]
  }
}

# GASTICO_STORAGE_SECRET del frontend: generado por Terraform y guardado como SecureString.
# Nunca pasa por una variable de Terraform ni por un log de CI; el contenedor lo recibe por
# "secrets" en la task definition (valueFrom), no por una variable de entorno en texto plano.
resource "random_password" "storage_secret" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "storage_secret" {
  name  = "/${var.project}/${var.environment}/storage-secret"
  type  = "SecureString"
  value = random_password.storage_secret.result
}
