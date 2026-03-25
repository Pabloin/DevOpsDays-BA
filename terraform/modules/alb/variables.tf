variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets for the ALB"
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. Leave empty to skip certificate attachment."
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Path for the ALB target group health check"
  type        = string
  default     = "/healthcheck"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
