variable "aws_region" {
  description = "Región de AWS (el Learner Lab solo permite us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Nombre corto del proyecto, usado como prefijo de los recursos"
  type        = string
  default     = "gastico"
}

variable "backend_image_tag" {
  description = "Tag de la imagen del backend en ECR a desplegar (sha-xxxxxxx en staging, vX.Y.Z en producción)"
  type        = string
}

variable "frontend_image_tag" {
  description = "Tag de la imagen del frontend en ECR a desplegar (sha-xxxxxxx en staging, vX.Y.Z en producción)"
  type        = string
}

variable "app_version" {
  description = "Versión que expone /health (normalmente igual al tag de la imagen)"
  type        = string
}
