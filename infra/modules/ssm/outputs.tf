output "current_name" {
  value = aws_ssm_parameter.current.name
}

output "last_good_name" {
  value = aws_ssm_parameter.last_good.name
}

output "storage_secret_arn" {
  value = aws_ssm_parameter.storage_secret.arn
}
