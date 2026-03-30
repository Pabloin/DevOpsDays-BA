variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "backstage-portal"
}

variable "environment" {
  description = "Environment name used for resource naming and tagging"
  type        = string
  default     = "mvp"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}
