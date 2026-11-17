variable "name" {
  description = "Nombre del repositorio (gastico-backend o gastico-frontend)"
  type        = string
}

variable "manage" {
  description = <<-EOT
    D5: un solo repositorio por servicio, compartido entre staging y producción (la misma
    imagen se promueve por digest). true crea el repositorio (lo hace el workspace "staging",
    por convención); false lo busca por nombre y lo reutiliza (el workspace "production").
  EOT
  type        = bool
}
