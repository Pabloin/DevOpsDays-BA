locals {
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS credentials secret
resource "aws_secretsmanager_secret" "rds" {
  name        = "${var.project}-${var.environment}-rds-credentials"
  description = "RDS master credentials for the ${var.project} ${var.environment} database"

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-rds-credentials" })
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.rds.result
    host     = var.rds_endpoint
    port     = 5432
  })
}

# GitHub OAuth credentials secret
resource "aws_secretsmanager_secret" "github" {
  name        = "${var.project}-${var.environment}-github-oauth"
  description = "GitHub OAuth credentials for the ${var.project} ${var.environment} environment"

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-github-oauth" })
}

resource "aws_secretsmanager_secret_version" "github" {
  secret_id = aws_secretsmanager_secret.github.id

  secret_string = jsonencode({
    AUTH_GITHUB_CLIENT_ID     = var.github_oauth_client_id
    AUTH_GITHUB_CLIENT_SECRET = var.github_oauth_client_secret
  })
}
