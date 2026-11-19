variable "name" {
  description = "Prefijo de los recursos (gastico-<env>)"
  type        = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "alb_arn_suffix" {
  description = "ALB público (frontend), para las métricas de AWS/ApplicationELB"
  type        = string
}

variable "frontend_target_group_arn_suffix" {
  type = string
}

variable "backend_alb_arn_suffix" {
  description = "ALB interno (backend)"
  type        = string
}

variable "backend_target_group_arn_suffix" {
  type = string
}

variable "frontend_service_name" {
  type = string
}

variable "backend_service_name" {
  type = string
}

variable "log_group_names" {
  description = "Logs de los dos servicios, para el panel de errores recientes"
  type        = list(string)
}

variable "latencia_p95_maxima" {
  description = "Segundos. Igual al umbral de k6 para la página (1.5 s)"
  type        = number
  default     = 1.5
}
