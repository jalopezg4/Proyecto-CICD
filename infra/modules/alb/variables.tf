variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_port" {
  description = "Puerto donde escucha el contenedor (backend: 8000, frontend: 8080)"
  type        = number
}

variable "listener_port" {
  description = "Puerto donde escucha el ALB. Por defecto igual a target_port; el ALB público usa 80"
  type        = number
  default     = null
}

variable "internal" {
  description = "true para el ALB interno del backend (sin salida a internet, D3)"
  type        = bool
  default     = false
}

variable "health_check_path" {
  type    = string
  default = "/health/live"
}

variable "sticky_sessions" {
  description = "D4: solo el frontend lo necesita (NiceGUI guarda estado por cliente)"
  type        = bool
  default     = true
}
