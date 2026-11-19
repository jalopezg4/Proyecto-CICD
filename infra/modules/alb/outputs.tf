output "dns_name" {
  value = aws_lb.este.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.este.arn
}

# Para las métricas de CloudWatch (dimensiones LoadBalancer y TargetGroup)
output "arn_suffix" {
  value = aws_lb.este.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.este.arn_suffix
}
