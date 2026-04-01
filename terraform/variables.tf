variable "github_repository" {
  description = "GitHub repository in org/repo format, used to scope the OIDC trust policy (e.g. 'Pabloin/DevOpsDays-BA')"
  type        = string
  default     = "Pabloin/DevOpsDays-BA"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used for tagging and resource naming"
  type        = string
  default     = "mvp"
}

variable "project" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "backstage"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of two availability zones for subnet distribution"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "domain_name" {
  description = "FQDN for the portal subdomain — a Route 53 hosted zone and ACM certificate will be created for this domain"
  type        = string
  default     = "portal.glaciar.org"
}

variable "image_tag" {
  description = "ECR image tag to deploy to ECS"
  type        = string
  default     = "latest"
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

variable "github_pat" {
  description = "GitHub Personal Access Token for the Backstage scaffolder"
  type        = string
  sensitive   = true
}

variable "image_retention_count" {
  description = "Number of ECR images to retain via lifecycle policy"
  type        = number
  default     = 10
}
