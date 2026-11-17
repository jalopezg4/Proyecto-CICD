output "frontend_url" {
  description = "URL del ALB para correr el smoke/E2E de este ambiente"
  value       = "http://${module.alb.dns_name}"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.este.name
}

output "backend_repository_url" {
  value = module.ecr_backend.repository_url
}

output "frontend_repository_url" {
  value = module.ecr_frontend.repository_url
}

output "ssm_current_name" {
  value = module.ssm.current_name
}

output "ssm_last_good_name" {
  value = module.ssm.last_good_name
}
