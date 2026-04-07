output "ecr_repository_url" {
  description = "ECR repository URL for pushing service images"
  value       = aws_ecr_repository.service.repository_url
}

output "service_url" {
  description = "Public URL of the deployed service"
  value       = local.service_url
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.service.name
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role (has Bedrock permissions)"
  value       = aws_iam_role.task.arn
}
