output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.este.dashboard_name}"
}

output "alarm_prefix" {
  description = "Todas las alarmas del ambiente empiezan así (lo usa evidencia-aws.sh)"
  value       = var.name
}
