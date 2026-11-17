variable "name" {
  description = "Prefijo de los recursos de este ambiente (p. ej. gastico-staging)"
  type        = string
}

variable "environment" {
  description = "staging o production: decide qué 2 subredes de la VPC por defecto usar"
  type        = string
}

variable "crear_s3_endpoint_compartido" {
  description = <<-EOT
    El VPC endpoint de interfaz para S3... en realidad es un endpoint de tipo Gateway, y un
    endpoint Gateway se asocia a tablas de rutas, no a subredes. Si staging y producción
    comparten tabla de rutas (normal en la VPC por defecto), solo uno de los dos workspaces
    puede crearlo: el otro lo reutiliza. true = este workspace lo crea (staging, por convención).
  EOT
  type        = bool
}
