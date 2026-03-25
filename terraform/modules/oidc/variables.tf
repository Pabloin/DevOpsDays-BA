variable "github_repository" {
  description = "GitHub repository in org/repo format, used to scope the OIDC trust policy (e.g. 'Pabloin/DevOpsDays-BA')"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the pipeline pushes images to"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster the pipeline deploys to"
  type        = string
}

variable "ecs_service_arn" {
  description = "ARN of the ECS service the pipeline updates"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role (for iam:PassRole)"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
