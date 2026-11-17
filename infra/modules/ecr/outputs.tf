locals {
  repo = var.manage ? aws_ecr_repository.este[0] : data.aws_ecr_repository.este[0]
}

output "repository_url" {
  value = local.repo.repository_url
}

output "repository_arn" {
  value = local.repo.arn
}

output "repository_name" {
  value = local.repo.name
}
