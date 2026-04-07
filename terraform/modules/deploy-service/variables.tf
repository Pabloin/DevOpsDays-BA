variable "service_name" {
  description = "Name of the scaffolded service (e.g. my-ai-assistant)"
  type        = string
}

variable "environment" {
  description = "Target environment: dev or prod"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for ECS tasks"
  type        = list(string)
}

variable "cluster_arn" {
  description = "ARN of the shared ECS cluster for this environment"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the shared ALB HTTPS listener to attach the listener rule to"
  type        = string
}

variable "alb_security_group_id" {
  description = "ID of the shared ALB security group — ECS task SG allows ingress from this"
  type        = string
}

variable "base_domain" {
  description = "Base domain (e.g. backstage.glaciar.org)"
  type        = string
  default     = "backstage.glaciar.org"
}

variable "bedrock_model_id" {
  description = "AWS Bedrock foundation model ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "aws_region" {
  description = "AWS region for Bedrock"
  type        = string
  default     = "us-east-1"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3001
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 1024
}

variable "image_tag" {
  description = "ECR image tag to deploy"
  type        = string
  default     = "latest"
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
