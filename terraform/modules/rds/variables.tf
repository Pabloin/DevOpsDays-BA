variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for the DB subnet group"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID of the ECS tasks (allowed to connect to RDS)"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS password"
  type        = string
}

variable "backup_retention_days" {
  description = "Number of days to retain automated RDS backups"
  type        = number
  default     = 7
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
