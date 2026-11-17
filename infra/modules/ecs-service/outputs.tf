output "service_name" {
  value = aws_ecs_service.este.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.este.name
}
