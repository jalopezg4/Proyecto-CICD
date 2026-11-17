variable "name" {
  description = "Prefijo de los recursos de este ambiente (p. ej. gastico-staging)"
  type        = string
}

variable "crear_s3_endpoint_compartido" {
  description = <<-EOT
    El endpoint Gateway de S3 se asocia a tablas de rutas, no a subredes. Si staging y
    producción comparten tabla de rutas (normal en la VPC por defecto), solo uno de los dos
    workspaces puede crearlo: el otro lo reutiliza. true = este workspace lo crea (staging,
    por convención).
  EOT
  type        = bool
}
