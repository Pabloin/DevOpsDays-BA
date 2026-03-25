output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer — use this for DNS configuration"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this in CI/CD to push images"
  value       = module.ecr.repository_url
}

output "rds_endpoint" {
  description = "RDS instance endpoint hostname"
  value       = module.rds.db_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name — use this in CI/CD to trigger deployments"
  value       = module.ecs.ecs_cluster_name
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — store as AWS_ROLE_ARN GitHub secret"
  value       = module.oidc.role_arn
}
