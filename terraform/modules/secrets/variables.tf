variable "rds_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "backstage"
}

variable "rds_endpoint" {
  description = "RDS instance endpoint hostname (set after RDS is created)"
  type        = string
  default     = ""
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth application client ID"
  type        = string
  sensitive   = true
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth application client secret"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
