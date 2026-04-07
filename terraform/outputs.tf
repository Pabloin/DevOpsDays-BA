output "portal_nameservers" {
  description = "Nameservers for the backstage.glaciar.org hosted zone — add these as an NS record for backstage.glaciar.org in the parent glaciar.org hosted zone (AWS account ***8689) to complete subdomain delegation"
  value       = module.dns.name_servers
}

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

output "terraform_provisioner_role_arn" {
  description = "ARN of the Terraform provisioner IAM role — store as TERRAFORM_ROLE_ARN GitHub secret"
  value       = aws_iam_role.terraform_provisioner.arn
}

# ─── Shared ECS: Dev ─────────────────────────────────────────────────────────

output "ecs_dev_cluster_name" {
  description = "ECS cluster name for the dev shared environment"
  value       = module.ecs_env_dev.cluster_name
}

output "ecs_dev_alb_listener_arn" {
  description = "HTTPS listener ARN for the dev ALB — services attach listener rules here"
  value       = module.ecs_env_dev.alb_listener_arn_https
}

output "ecs_dev_alb_sg_id" {
  description = "ALB security group ID for the dev environment"
  value       = module.ecs_env_dev.alb_security_group_id
}

output "ecs_dev_subdomain" {
  description = "Dev environment subdomain (e.g. dev.backstage.glaciar.org)"
  value       = module.ecs_env_dev.subdomain
}

output "ecs_dev_alb_dns_name" {
  description = "DNS name of the dev shared ECS environment ALB"
  value       = module.ecs_env_dev.alb_dns_name
}

# ─── Shared ECS: Prod ────────────────────────────────────────────────────────

output "ecs_prod_cluster_name" {
  description = "ECS cluster name for the prod shared environment"
  value       = module.ecs_env_prod.cluster_name
}

output "ecs_prod_alb_listener_arn" {
  description = "HTTPS listener ARN for the prod ALB — services attach listener rules here"
  value       = module.ecs_env_prod.alb_listener_arn_https
}

output "ecs_prod_alb_sg_id" {
  description = "ALB security group ID for the prod environment"
  value       = module.ecs_env_prod.alb_security_group_id
}

output "ecs_prod_subdomain" {
  description = "Prod environment subdomain (e.g. prod.backstage.glaciar.org)"
  value       = module.ecs_env_prod.subdomain
}

output "ecs_prod_alb_dns_name" {
  description = "DNS name of the prod shared ECS environment ALB"
  value       = module.ecs_env_prod.alb_dns_name
}
