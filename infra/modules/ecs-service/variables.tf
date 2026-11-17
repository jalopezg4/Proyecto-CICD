variable "name" {
  description = "Nombre de la tarea/servicio (p. ej. gastico-staging-backend)"
  type        = string
}

variable "cluster_arn" {
  type = string
}

variable "image" {
  description = "URL completa de la imagen en ECR, con tag (repo:tag)"
  type        = string
}

variable "container_port" {
  type = number
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "execution_role_arn" {
  description = "LabRole: el Learner Lab no permite crear roles IAM propios"
  type        = string
}

variable "task_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "assign_public_ip" {
  type = bool
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secrets" {
  description = "Variables que se inyectan desde SSM (valueFrom), no en texto plano: nombre -> ARN del parámetro"
  type        = map(string)
  default     = {}
}

variable "service_connect_namespace_arn" {
  type = string
}

variable "service_connect_alias" {
  description = "Nombre DNS dentro del namespace (\"backend\" o \"frontend\")"
  type        = string
}

variable "target_group_arn" {
  description = "Solo el frontend lo usa; el backend no tiene ALB (D3)"
  type        = string
  default     = null
}

variable "health_check_grace_period" {
  type    = number
  default = 30
}
