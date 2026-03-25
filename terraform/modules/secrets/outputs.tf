output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds.arn
}

output "github_secret_arn" {
  description = "ARN of the Secrets Manager secret containing GitHub OAuth credentials"
  value       = aws_secretsmanager_secret.github.arn
}

output "rds_username" {
  description = "RDS master username"
  value       = var.rds_username
}
