# Scaffolded service deployments
# This file is managed by the deploy-service.yml GitHub Actions workflow.
# Each module block below represents one service deployed to one environment.
# Do not edit manually.

module "svc_test_reflection_ai_02_dev" {
  source = "./modules/deploy-service"

  service_name          = "test-reflection-ai-02"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_test_reflection_ai_03_dev" {
  source = "./modules/deploy-service"

  service_name          = "test-reflection-ai-03"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_test_reflection_ai_04_dev" {
  source = "./modules/deploy-service"

  service_name          = "test-reflection-ai-04"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "amazon.nova-pro-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_repo_ai_25_dev" {
  source = "./modules/deploy-service"

  service_name          = "repo-ai-25"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_delic_ia_dev" {
  source = "./modules/deploy-service"

  service_name          = "delic-ia"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_test_22_dev" {
  source = "./modules/deploy-service"

  service_name          = "test-22"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-5-sonnet-20240620-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_enfermar_ia_dev" {
  source = "./modules/deploy-service"

  service_name          = "enfermar-ia"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_repo_42_ia_dev" {
  source = "./modules/deploy-service"

  service_name          = "repo-42-ia"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}

module "svc_repo_43_ia_dev" {
  source = "./modules/deploy-service"

  service_name          = "repo-43-ia"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  image_tag             = "latest"
  project               = "backstage"
}
