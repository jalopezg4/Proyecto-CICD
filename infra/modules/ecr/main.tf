# D5: tags inmutables (la imagen probada en staging es, por digest, la misma que llega a
# producción) y escaneo de vulnerabilidades al subir.
resource "aws_ecr_repository" "este" {
  count                = var.manage ? 1 : 0
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  # Sin esto, "terraform destroy" falla si el repo tiene imágenes, y en la demo siempre
  # las va a tener.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Proyecto = "gastico" }
}

data "aws_ecr_repository" "este" {
  count = var.manage ? 0 : 1
  name  = var.name
}
