provider "aws" {
  region = var.aws_region
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones   = var.availability_zones

  environment = var.environment
  project     = var.project
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

module "ecr" {
  source = "./modules/ecr"

  repository_name       = "${var.project}-${var.environment}"
  image_retention_count = var.image_retention_count

  environment = var.environment
  project     = var.project
}

# ─── Secrets ─────────────────────────────────────────────────────────────────

module "secrets" {
  source = "./modules/secrets"

  github_oauth_client_id     = var.github_oauth_client_id
  github_oauth_client_secret = var.github_oauth_client_secret
  github_pat                 = var.github_pat
  rds_endpoint               = module.rds.db_endpoint

  environment = var.environment
  project     = var.project
}

# ─── ALB ─────────────────────────────────────────────────────────────────────

module "alb" {
  source = "./modules/alb"

  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  acm_certificate_arn = module.dns.certificate_arn

  environment = var.environment
  project     = var.project
}

# ─── DNS ─────────────────────────────────────────────────────────────────────

module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_name

  environment = var.environment
  project     = var.project
}

# ─── ECS Security Group (root-level to break RDS ↔ ECS circular dependency) ──
# RDS needs the ECS SG ID for its ingress rule.
# ECS needs the RDS endpoint for its task definition.
# Extracting the SG here lets both modules reference it without a cycle.

resource "aws_security_group" "ecs" {
  name        = "${var.project}-${var.environment}-ecs-sg"
  description = "Allow traffic from ALB to ECS tasks on port 7007"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = 7007
    to_port         = 7007
    protocol        = "tcp"
    security_groups = [module.alb.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = var.project
  }
}

# ─── RDS ─────────────────────────────────────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = aws_security_group.ecs.id
  db_username           = module.secrets.rds_username
  rds_secret_arn        = module.secrets.rds_secret_arn

  environment = var.environment
  project     = var.project
}

# ─── ECS ─────────────────────────────────────────────────────────────────────

module "ecs" {
  source = "./modules/ecs"

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  target_group_arn      = module.alb.target_group_arn
  ecs_security_group_id = aws_security_group.ecs.id

  ecr_repository_url = module.ecr.repository_url
  image_tag          = var.image_tag

  rds_secret_arn    = module.secrets.rds_secret_arn
  github_secret_arn = module.secrets.github_secret_arn

  db_endpoint = module.rds.db_endpoint
  db_port     = module.rds.db_port

  app_base_url = "https://${var.domain_name}"

  environment = var.environment
  project     = var.project
}

# ─── OIDC (GitHub Actions) ────────────────────────────────────────────────────

module "oidc" {
  source = "./modules/oidc"

  github_repository      = var.github_repository
  ecr_repository_arn     = module.ecr.repository_arn
  ecs_cluster_arn        = module.ecs.ecs_cluster_arn
  ecs_service_arn        = module.ecs.ecs_service_arn
  ecs_execution_role_arn = module.ecs.ecs_task_execution_role_arn
  ecs_task_role_arn      = module.ecs.ecs_task_role_arn

  environment = var.environment
  project     = var.project
}
