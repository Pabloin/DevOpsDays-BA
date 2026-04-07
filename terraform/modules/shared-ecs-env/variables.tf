variable "environment" {
  description = "Environment name: dev or prod"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for the ALB"
  type        = list(string)
}

variable "base_domain" {
  description = "Base domain (e.g. glaciar.org) — a hosted zone will be created for {environment}.{base_domain}"
  type        = string
  default     = "glaciar.org"
}

variable "project" {
  description = "Project name for tagging and resource naming"
  type        = string
}
