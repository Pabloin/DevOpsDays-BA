variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks (created in root to avoid circular dependency with RDS)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  type        = string
}

variable "github_secret_arn" {
  description = "ARN of the Secrets Manager secret containing GitHub OAuth credentials"
  type        = string
}

variable "db_endpoint" {
  description = "Hostname of the RDS instance"
  type        = string
}

variable "db_port" {
  description = "Port of the RDS instance"
  type        = number
}

variable "app_base_url" {
  description = "Base URL of the Backstage app (e.g. https://backstage.example.com)"
  type        = string
  default     = ""
}

variable "route53_hosted_zone_arn" {
  description = "ARN of the Route53 hosted zone for DNS record management"
  type        = string
}

variable "route53_hosted_zone_id" {
  description = "ID of the Route53 hosted zone (passed as env var to Backstage)"
  type        = string
}

variable "route53_domain_name" {
  description = "Base domain name for scaffolded apps (e.g. backstage.glaciar.org)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB for Route53 alias records"
  type        = string
}

variable "alb_hosted_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  type        = string
}

variable "cpu" {
  description = "CPU units for the ECS task (1 vCPU = 1024)"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory in MiB for the ECS task"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of ECS task instances"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
