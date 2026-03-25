# Implementation Plan: AWS Infrastructure

## Overview

Provision all AWS infrastructure for the Backstage portal using Terraform. All Terraform code lives in `terraform/` at the repo root. The implementation order follows dependency chains: bootstrap → VPC → ECR/Secrets → RDS → ALB → ECS → root wiring → app-config update → tests.

## Tasks

- [ ] 1. Terraform bootstrap (S3 + DynamoDB state backend)
  - [ ] 1.1 Create `terraform/bootstrap/` with `main.tf`, `variables.tf`, `outputs.tf`
    - `aws_s3_bucket` with versioning enabled, SSE-S3 encryption, and public access block
    - `aws_dynamodb_table` with `LockID` hash key (string) for state locking
    - Tag both resources with `Environment` and `Project`
    - _Requirements: 1.1, 1.2, 1.4, 1.5, 9.4_
  - [ ]* 1.2 Write property test for state backend (P7: Resource Tagging)
    - **Property 7: Resource Tagging Invariant**
    - **Validates: Requirements 9.4**
    - Parse `terraform plan -json` output for bootstrap module; assert every resource has `Environment` and `Project` tags

- [ ] 2. Root module scaffolding (`terraform/`)
  - [ ] 2.1 Create `terraform/versions.tf` declaring required Terraform version (`>= 1.5`) and AWS provider (`~> 5.0`)
    - _Requirements: 9.1, 9.7_
  - [ ] 2.2 Create `terraform/backend.tf` with the S3 backend block (bucket, key, region, encrypt, dynamodb_table)
    - _Requirements: 1.1, 1.2, 1.3_
  - [ ] 2.3 Create `terraform/variables.tf` with all root-level variables: `aws_region`, `environment`, `project`, `vpc_cidr`, `availability_zones`, `acm_certificate_arn`, `image_tag`, `github_oauth_client_id` (sensitive), `github_oauth_client_secret` (sensitive), `backup_retention_days`, `image_retention_count`
    - Use MVP-appropriate defaults as specified in the design
    - _Requirements: 9.2, 9.3, 9.5_
  - [ ] 2.4 Create `terraform/outputs.tf` declaring the four root outputs: `alb_dns_name`, `ecr_repository_url`, `rds_endpoint`, `ecs_cluster_name`
    - _Requirements: 9.6_
  - [ ] 2.5 Create `terraform/terraform.tfvars.example` with placeholder values for all required variables
    - _Requirements: 9.5_

- [ ] 3. VPC module (`terraform/modules/vpc/`)
  - [ ] 3.1 Create `terraform/modules/vpc/variables.tf` and `terraform/modules/vpc/outputs.tf`
    - Inputs: `vpc_cidr`, `public_subnet_cidrs`, `private_subnet_cidrs`, `availability_zones`, `environment`, `project`
    - Outputs: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`
    - _Requirements: 2.1, 9.1_
  - [ ] 3.2 Create `terraform/modules/vpc/main.tf` implementing all VPC resources
    - `aws_vpc`, 2× public `aws_subnet`, 2× private `aws_subnet` (each in a distinct AZ)
    - `aws_internet_gateway`, `aws_eip`, `aws_nat_gateway` (single, in first public subnet)
    - Public route table: `0.0.0.0/0 → IGW`; private route table: `0.0.0.0/0 → NAT`
    - 4× `aws_route_table_association`
    - Tag all resources with `Environment` and `Project`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 9.4_
  - [ ]* 3.3 Write property test for VPC module (P1: Subnet AZ Distribution)
    - **Property 1: Subnet AZ Distribution**
    - **Validates: Requirements 2.2, 2.3**
    - Table-driven test with varied AZ pairs; assert `public_subnet_ids` and `private_subnet_ids` each have ≥ 2 entries in distinct AZs from plan JSON
  - [ ]* 3.4 Write property test for VPC module (P2: Route Table Correctness)
    - **Property 2: Route Table Correctness**
    - **Validates: Requirements 2.6, 2.7**
    - Parse plan JSON; for each route table association assert public subnets route to IGW and private subnets route to NAT Gateway, never to IGW directly

- [ ] 4. ECR module (`terraform/modules/ecr/`)
  - [ ] 4.1 Create `terraform/modules/ecr/variables.tf` and `terraform/modules/ecr/outputs.tf`
    - Inputs: `repository_name`, `image_retention_count` (default 10), `environment`, `project`
    - Outputs: `repository_url`, `repository_arn`
    - _Requirements: 3.1, 9.1_
  - [ ] 4.2 Create `terraform/modules/ecr/main.tf`
    - `aws_ecr_repository` with `image_tag_mutability = "IMMUTABLE"` and `scan_on_push = true`
    - `aws_ecr_lifecycle_policy` retaining the most recent N images (from `image_retention_count`)
    - Tag with `Environment` and `Project`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 9.4_

- [ ] 5. Secrets module (`terraform/modules/secrets/`)
  - [ ] 5.1 Create `terraform/modules/secrets/variables.tf` and `terraform/modules/secrets/outputs.tf`
    - Inputs: `rds_username` (default `"backstage"`), `github_oauth_client_id` (sensitive), `github_oauth_client_secret` (sensitive), `environment`, `project`
    - Outputs: `rds_secret_arn`, `github_secret_arn`, `rds_username`
    - _Requirements: 5.1, 5.2, 9.1_
  - [ ] 5.2 Create `terraform/modules/secrets/main.tf`
    - `random_password` resource for RDS master password (never output)
    - `aws_secretsmanager_secret` + `aws_secretsmanager_secret_version` for RDS credentials (JSON with `username`, `password`, `host`, `port` fields)
    - `aws_secretsmanager_secret` + `aws_secretsmanager_secret_version` for GitHub OAuth (`AUTH_GITHUB_CLIENT_ID`, `AUTH_GITHUB_CLIENT_SECRET`)
    - Tag both secrets with `Environment` and `Project`
    - _Requirements: 4.9, 5.1, 5.2, 9.4_

- [ ] 6. RDS module (`terraform/modules/rds/`)
  - [ ] 6.1 Create `terraform/modules/rds/variables.tf` and `terraform/modules/rds/outputs.tf`
    - Inputs: `vpc_id`, `private_subnet_ids`, `ecs_security_group_id`, `db_username`, `rds_secret_arn`, `backup_retention_days` (default 7), `environment`, `project`
    - Outputs: `db_endpoint`, `db_port`, `db_security_group_id`
    - _Requirements: 4.1, 9.1_
  - [ ] 6.2 Create `terraform/modules/rds/main.tf`
    - `aws_db_subnet_group` spanning private subnets
    - `aws_security_group` (RDS SG): ingress port 5432 from `ecs_security_group_id` only, egress all
    - `aws_db_instance`: engine `postgres`, engine_version `16`, instance_class `db.t3.micro`, allocated_storage `20`, storage_type `gp2`, multi_az `false`, publicly_accessible `false`, deletion_protection `false`, backup_retention_period from variable, manage_master_user_password or password from secrets module
    - Tag all resources with `Environment` and `Project`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 9.4_
  - [ ]* 6.3 Write property test for RDS module (P3: RDS SG Least Privilege)
    - **Property 3: RDS Security Group Least Privilege**
    - **Validates: Requirements 4.4**
    - Parse plan JSON; assert every ingress rule on the RDS security group references only the ECS task SG ID as source — no CIDR blocks, no wildcards

- [ ] 7. ALB module (`terraform/modules/alb/`)
  - [ ] 7.1 Create `terraform/modules/alb/variables.tf` and `terraform/modules/alb/outputs.tf`
    - Inputs: `vpc_id`, `public_subnet_ids`, `acm_certificate_arn` (default `""`), `health_check_path` (default `"/healthcheck"`), `environment`, `project`
    - Outputs: `alb_dns_name`, `alb_security_group_id`, `target_group_arn`
    - _Requirements: 7.1, 9.1_
  - [ ] 7.2 Create `terraform/modules/alb/main.tf`
    - `aws_security_group` (ALB SG): ingress 80 and 443 from `0.0.0.0/0`, egress all
    - `aws_lb` (internal = false) in public subnets
    - `aws_lb_target_group`: port 7007, protocol HTTP, health check on `health_check_path`, healthy_threshold 2, unhealthy_threshold 2
    - `aws_lb_listener` port 80: redirect to HTTPS 443
    - `aws_lb_listener` port 443: forward to target group, attach ACM cert when `acm_certificate_arn != ""`
    - Tag all resources with `Environment` and `Project`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 9.4_

- [ ] 8. ECS module (`terraform/modules/ecs/`)
  - [ ] 8.1 Create `terraform/modules/ecs/variables.tf` and `terraform/modules/ecs/outputs.tf`
    - Inputs: `vpc_id`, `private_subnet_ids`, `alb_security_group_id`, `target_group_arn`, `ecr_repository_url`, `image_tag` (default `"latest"`), `rds_secret_arn`, `github_secret_arn`, `db_endpoint`, `db_port`, `cpu` (default 512), `memory` (default 1024), `desired_count` (default 1), `environment`, `project`
    - Outputs: `ecs_cluster_name`, `ecs_task_execution_role_arn`, `ecs_task_role_arn`, `ecs_security_group_id`
    - _Requirements: 6.1, 9.1_
  - [ ] 8.2 Create IAM roles in `terraform/modules/ecs/main.tf`
    - ECS task execution role: assume-role for `ecs-tasks.amazonaws.com`, attach `AmazonECSTaskExecutionRolePolicy`, inline policy granting `secretsmanager:GetSecretValue` on `rds_secret_arn` and `github_secret_arn` only
    - ECS task role: assume-role for `ecs-tasks.amazonaws.com`, no additional permissions (MVP placeholder)
    - _Requirements: 6.9, 6.10, 5.4_
  - [ ] 8.3 Create ECS cluster, security group, CloudWatch log group, task definition, and service in `terraform/modules/ecs/main.tf`
    - `aws_security_group` (ECS SG): ingress port 7007 from `alb_security_group_id` only, egress all
    - `aws_cloudwatch_log_group` for container logs
    - `aws_ecs_cluster`
    - `aws_ecs_task_definition`: Fargate, cpu/memory from variables, container def with `secrets` block for `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `AUTH_GITHUB_CLIENT_ID`, `AUTH_GITHUB_CLIENT_SECRET`; `environment` block for `NODE_ENV=production` and `PGSSLMODE=require`; `APP_BASE_URL` as non-sensitive env var
    - `aws_ecs_service`: desired_count from variable, network config in private subnets, load_balancer block pointing to target group on port 7007
    - Tag all resources with `Environment` and `Project`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.11, 5.3, 5.5, 9.4_
  - [ ]* 8.4 Write property test for ECS module (P4: ECS SG Least Privilege)
    - **Property 4: ECS Security Group Least Privilege**
    - **Validates: Requirements 6.6**
    - Parse plan JSON; assert every ingress rule on the ECS task security group references only the ALB SG ID — no CIDR blocks, no wildcards
  - [ ]* 8.5 Write property test for ECS module (P5: Secrets Injection via Secrets Manager)
    - **Property 5: Secrets Injection via Secrets Manager**
    - **Validates: Requirements 5.3, 6.3**
    - Parse task definition container JSON from plan; assert `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `AUTH_GITHUB_CLIENT_ID`, `AUTH_GITHUB_CLIENT_SECRET` appear in `secrets` block and not in `environment` block as plaintext
  - [ ]* 8.6 Write property test for ECS module (P6: IAM Least Privilege for Secrets Access)
    - **Property 6: IAM Least Privilege for Secrets Access**
    - **Validates: Requirements 5.4, 6.9**
    - Parse IAM policy JSON from plan; assert no `secretsmanager:GetSecretValue` statement has `Resource: "*"` — all resources must be specific ARNs

- [ ] 9. Checkpoint — ensure all modules are syntactically valid
  - Run `terraform validate` in each module directory and in `terraform/`; ensure all modules pass with no errors. Ask the user if questions arise.

- [ ] 10. Root module wiring (`terraform/main.tf`)
  - [ ] 10.1 Create `terraform/main.tf` calling all six modules in dependency order
    - Configure AWS provider with `aws_region` variable
    - Call `module.vpc` → pass outputs to `module.rds`, `module.alb`, `module.ecs`
    - Call `module.ecr` (no VPC dependency)
    - Call `module.secrets` → pass `rds_secret_arn` and `github_secret_arn` to `module.ecs`; pass `rds_username` to `module.rds`
    - Call `module.rds` → pass `db_endpoint`, `db_port`, `db_security_group_id` to `module.ecs`
    - Call `module.alb` → pass `alb_security_group_id`, `target_group_arn` to `module.ecs`
    - Call `module.ecs` with all assembled inputs
    - Wire root `outputs.tf` to module outputs
    - _Requirements: 9.1, 9.2, 9.3, 9.6, 9.7_
  - [ ]* 10.2 Write property test for root module (P7: Resource Tagging Invariant)
    - **Property 7: Resource Tagging Invariant**
    - **Validates: Requirements 9.4**
    - Run `terraform plan -json` on root module with sample tfvars; iterate all `resource_changes`; assert every planned resource has `Environment` and `Project` tags in `after` attributes
  - [ ]* 10.3 Write property test for root module (P8: Valid Terraform Plan)
    - **Property 8: Valid Terraform Plan**
    - **Validates: Requirements 9.7**
    - Table-driven test with varied valid input combinations (different regions, environment names, image tags); assert `terraform plan` exits 0 with no errors for each combination

- [ ] 11. Update `backstage-portal/app-config.production.yaml`
  - [ ] 11.1 Set `app.baseUrl` and `backend.baseUrl` to `${APP_BASE_URL}` (env var injected by ECS task definition)
  - [ ] 11.2 Update `backend.database` connection to use `host: ${POSTGRES_HOST}`, `port: ${POSTGRES_PORT}`, `user: ${POSTGRES_USER}`, `password: ${POSTGRES_PASSWORD}` with `ssl.rejectUnauthorized: false`
  - [ ] 11.3 Verify `auth.providers.github` already reads `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET` from env vars (no change needed if already correct)
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 12. Terratest suite setup (`terraform/test/`)
  - [ ] 12.1 Create `terraform/test/go.mod` and `terraform/test/go.sum` initializing a Go module with Terratest dependency (`github.com/gruntwork-io/terratest`)
    - _Requirements: 9.7_
  - [ ] 12.2 Create `terraform/test/helpers_test.go` with shared helpers: `runTerraformPlanJSON(t, moduleDir, vars)` returning parsed plan JSON, and `assertTagsOnAllResources(t, planJSON, env, project)` for reuse across property tests
    - _Requirements: 9.4, 9.7_
  - [ ] 12.3 Create `terraform/test/vpc_test.go` implementing property tests P1 and P2 as table-driven Go tests using plan JSON
    - _Requirements: 2.2, 2.3, 2.6, 2.7_
  - [ ] 12.4 Create `terraform/test/rds_test.go` implementing property test P3 using plan JSON
    - _Requirements: 4.4_
  - [ ] 12.5 Create `terraform/test/ecs_test.go` implementing property tests P4, P5, and P6 using plan JSON
    - _Requirements: 5.3, 5.4, 6.3, 6.6, 6.9_
  - [ ] 12.6 Create `terraform/test/root_test.go` implementing property tests P7 and P8 using plan JSON against the root module
    - _Requirements: 9.4, 9.7_

- [ ] 13. Final checkpoint — validate everything wires together
  - Run `terraform validate` and `terraform plan` (with example tfvars) against the root module; confirm plan produces no errors and all four outputs are present. Ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- All Terraform lives in `terraform/` at the repo root, not inside `backstage-portal/`
- Bootstrap (`terraform/bootstrap/`) must be applied before `terraform init` on the root module
- Property tests use plan-time JSON parsing (no real AWS account needed for CI)
- `github_oauth_client_id` and `github_oauth_client_secret` have no defaults — supply via `terraform.tfvars` or `TF_VAR_*` env vars
