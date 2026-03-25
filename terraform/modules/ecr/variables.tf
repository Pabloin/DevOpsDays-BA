variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_retention_count" {
  description = "Number of images to retain via lifecycle policy"
  type        = number
  default     = 10
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
