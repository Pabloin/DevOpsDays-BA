# Design Document: AWS Infrastructure

## Overview

This document describes the AWS infrastructure for deploying the Backstage developer portal using Terraform and ECS Fargate. The infrastructure is sized for MVP use (~$50–70/month) and is explicitly not production-grade.

The Backstage backend container runs as a single ECS Fargate task behind an Application Load Balancer. It connects to a managed PostgreSQL database on RDS. All sensitive configuration is stored in AWS Secrets Manager and injected into the container at runtime. Terraform state is stored remotely in S3 with DynamoDB locking.

### Key Design Decisions

- **Single NAT Gateway**: MVP cost constraint. Not HA — acceptable for dev/staging use.
- **Single-AZ RDS**: MVP cost constraint. No Multi-AZ standby.
- **Desired count = 1**: No auto-scaling. One task at all times.
- **Secrets Manager for all secrets**: RDS password is never in Terraform state as plaintext; GitHub OAuth credentials are injected at task start.
- **OIDC-based CI/CD**: GitHub Actions will assume an IAM role via OIDC (spec 03). No long-lived credentials.

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                          │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  Public Subnet AZ-a  │  │  Public Subnet AZ-b  │        │
│  │  10.0.1.0/24         │  │  10.0.2.0/24         │        │
│  │                      │  │                      │        │
│  │  ┌────────────────┐  │  │                      │        │
│  │  │  NAT Gateway   │  │  │                      │        │
│  │  └────────────────┘  │  │                      │        │
│  │                      │  │                      │        │
│  │  ┌────────────────────────────────────────┐    │        │
│  │  │  ALB (spans both public subnets)       │    │        │
│  │  │  :80 → redirect :443                   │    │        │
│  │  │  :443 → Target Group → ECS :7007       │    │        │
│  │  └────────────────────────────────────────┘    │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │  Private Subnet AZ-a │  │  Private Subnet AZ-b │        │
│  │  10.0.3.0/24         │  │  10.0.4.0/24         │        │
│  │                      │  │                      │        │
│  │  ┌────────────────┐  │  │                      │        │
│  │  │  ECS Fargate   │  │  │                      │        │
│  │  │  Task :7007    │  │  │                      │        │
│  │  └───────┬────────┘  │  │                      │        │
│  │          │           │  │                      │        │
│  │  ┌───────▼────────┐  │  │  ┌────────────────┐  │        │
│  │  │  RDS Postgres  │  │  │  │  RDS (standby) │  │        │
│  │  │  :5432         │  │  │  │  (not used MVP)│  │        │
│  │  └────────────────┘  │  │  └────────────────┘  │        │
│  └──────────────────────┘  └──────────────────────┘        │
│                                                             │
│  Internet Gateway (attached to VPC)                         │
└─────────────────────────────────────────────────────────────┘

AWS Services (outside VPC):
  ECR ← ECS pulls image via NAT Gateway
  Secrets Manager ← ECS reads secrets via NAT Gateway
  S3 + DynamoDB ← Terraform state backend
```

### Traffic Flow

1. Browser → ALB (public, port 443)
2. ALB → ECS task (private subnet, port 7007) via Target Group
3. ECS task → RDS (private subnet, port 5432) via security group rule
4. ECS task → ECR / Secrets Manager (via NAT Gateway → Internet Gateway)
5. HTTP port 80 → redirected to HTTPS by ALB listener rule

---

## Terraform Directory Structure

```
terraform/
├── main.tf                  # Root module: calls all child modules
├── variables.tf             # Root-level input variables
├── outputs.tf               # Root-level outputs
├── versions.tf              # Required providers and Terraform version
├── backend.tf               # S3 + DynamoDB remote state configuration
├── terraform.tfvars.example # Example variable values
│
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ecr/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── secrets/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ecs/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

The root `main.tf` wires modules together, passing outputs from one module as inputs to the next (e.g., VPC subnet IDs → ECS, RDS, ALB modules).

---

## Components and Interfaces

### State Backend (`backend.tf`)

Bootstrapped separately (S3 bucket and DynamoDB table created before `terraform init`). The bucket and table names are passed as backend configuration.

```hcl
terraform {
  backend "s3" {
    bucket         = "<project>-tfstate"
    key            = "mvp/terraform.tfstate"
    region         = "<aws_region>"
    encrypt        = true
    dynamodb_table = "<project>-tfstate-lock"
  }
}
```

The bootstrap resources (S3 bucket + DynamoDB table) are defined in a separate `bootstrap/` directory or created manually before first `terraform init`.

### VPC Module

Responsibilities: VPC, subnets, IGW, NAT Gateway, route tables.

Inputs:
- `vpc_cidr` (default `"10.0.0.0/16"`)
- `public_subnet_cidrs` (default `["10.0.1.0/24", "10.0.2.0/24"]`)
- `private_subnet_cidrs` (default `["10.0.3.0/24", "10.0.4.0/24"]`)
- `availability_zones` (list of 2 AZs in the region)
- `environment`, `project`

Outputs:
- `vpc_id`
- `public_subnet_ids` (list)
- `private_subnet_ids` (list)

Resources: `aws_vpc`, `aws_subnet` (×4), `aws_internet_gateway`, `aws_eip`, `aws_nat_gateway` (×1), `aws_route_table` (×2: public + private), `aws_route_table_association` (×4).

### ECR Module

Responsibilities: ECR repository with lifecycle policy.

Inputs:
- `repository_name` (e.g., `"backstage"`)
- `image_retention_count` (default `10`)
- `environment`, `project`

Outputs:
- `repository_url`
- `repository_arn`

Resources: `aws_ecr_repository`, `aws_ecr_lifecycle_policy`.

### Secrets Module

Responsibilities: Secrets Manager secrets for RDS credentials and GitHub OAuth.

Inputs:
- `rds_username` (default `"backstage"`)
- `github_oauth_client_id` (sensitive, no default — must be provided)
- `github_oauth_client_secret` (sensitive, no default — must be provided)
- `environment`, `project`

Outputs:
- `rds_secret_arn`
- `github_secret_arn`
- `rds_username`

Resources: `aws_secretsmanager_secret` (×2), `aws_secretsmanager_secret_version` (×2). The RDS password is generated via `random_password` and stored in the secret; it is never an output.

### RDS Module

Responsibilities: RDS PostgreSQL instance, DB subnet group, security group.

Inputs:
- `vpc_id`
- `private_subnet_ids`
- `ecs_security_group_id` (for SG ingress rule)
- `db_username` (from secrets module output)
- `rds_secret_arn` (for manage_master_user_password or password reference)
- `backup_retention_days` (default `7`)
- `environment`, `project`

Outputs:
- `db_endpoint`
- `db_port`
- `db_security_group_id`

Resources: `aws_db_instance`, `aws_db_subnet_group`, `aws_security_group` (RDS SG).

MVP settings hardcoded as variable defaults: `instance_class = "db.t3.micro"`, `allocated_storage = 20`, `storage_type = "gp2"`, `multi_az = false`, `publicly_accessible = false`, `deletion_protection = false`, `engine = "postgres"`, `engine_version = "16"`.

### ALB Module

Responsibilities: ALB, listeners (HTTP redirect + HTTPS forward), target group, security group.

Inputs:
- `vpc_id`
- `public_subnet_ids`
- `acm_certificate_arn` (optional, empty string = no HTTPS cert)
- `health_check_path` (default `"/healthcheck"`)
- `environment`, `project`

Outputs:
- `alb_dns_name`
- `alb_security_group_id`
- `target_group_arn`

Resources: `aws_lb`, `aws_lb_listener` (×2: HTTP redirect + HTTPS), `aws_lb_target_group`, `aws_security_group` (ALB SG).

### ECS Module

Responsibilities: ECS cluster, task definition, service, IAM roles, security group.

Inputs:
- `vpc_id`
- `private_subnet_ids`
- `alb_security_group_id`
- `target_group_arn`
- `ecr_repository_url`
- `image_tag` (default `"latest"`)
- `rds_secret_arn`
- `github_secret_arn`
- `db_endpoint`
- `db_port`
- `cpu` (default `512`)
- `memory` (default `1024`)
- `desired_count` (default `1`)
- `environment`, `project`

Outputs:
- `ecs_cluster_name`
- `ecs_task_execution_role_arn`
- `ecs_task_role_arn`
- `ecs_security_group_id`

Resources: `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service`, `aws_security_group` (ECS SG), `aws_iam_role` (×2: execution + task), `aws_iam_role_policy` (×2), `aws_cloudwatch_log_group`.

---

## Data Models

### Root Module Variables (`variables.tf`)

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `"us-east-1"` | AWS region for all resources |
| `environment` | string | `"mvp"` | Environment name for tagging and naming |
| `project` | string | `"backstage"` | Project name for tagging and naming |
| `vpc_cidr` | string | `"10.0.0.0/16"` | VPC CIDR block |
| `availability_zones` | list(string) | `["us-east-1a", "us-east-1b"]` | Two AZs for subnet distribution |
| `acm_certificate_arn` | string | `""` | ACM cert ARN for HTTPS listener (empty = no cert) |
| `image_tag` | string | `"latest"` | ECR image tag to deploy |
| `github_oauth_client_id` | string | — | GitHub OAuth client ID (sensitive) |
| `github_oauth_client_secret` | string | — | GitHub OAuth client secret (sensitive) |
| `backup_retention_days` | number | `7` | RDS automated backup retention |
| `image_retention_count` | number | `10` | ECR lifecycle policy image count |

### Root Module Outputs (`outputs.tf`)

| Output | Source | Description |
|---|---|---|
| `alb_dns_name` | `module.alb.alb_dns_name` | ALB DNS name for DNS configuration |
| `ecr_repository_url` | `module.ecr.repository_url` | ECR URL for CI/CD image push |
| `rds_endpoint` | `module.rds.db_endpoint` | RDS hostname for debugging |
| `ecs_cluster_name` | `module.ecs.ecs_cluster_name` | ECS cluster name for deployments |

### ECS Task Definition Container Environment

The task definition injects the following from Secrets Manager via the `secrets` block (not `environment`):

| Env Var | Source Secret | Description |
|---|---|---|
| `POSTGRES_HOST` | RDS secret (host field) | RDS endpoint |
| `POSTGRES_PORT` | RDS secret (port field) | RDS port (5432) |
| `POSTGRES_USER` | RDS secret (username field) | DB username |
| `POSTGRES_PASSWORD` | RDS secret (password field) | DB password |
| `AUTH_GITHUB_CLIENT_ID` | GitHub secret | GitHub OAuth client ID |
| `AUTH_GITHUB_CLIENT_SECRET` | GitHub secret | GitHub OAuth client secret |

Non-sensitive environment variables passed directly:
- `NODE_ENV=production`
- `PGSSLMODE=require`

### IAM Roles

**ECS Task Execution Role** (`backstage-mvp-ecs-execution-role`):
- Managed policy: `AmazonECSTaskExecutionRolePolicy` (ECR pull, CloudWatch logs)
- Inline policy: `secretsmanager:GetSecretValue` on the two specific secret ARNs

**ECS Task Role** (`backstage-mvp-ecs-task-role`):
- Minimal permissions for the running container
- For MVP: no additional permissions needed beyond what the execution role provides
- Placeholder for future permissions (e.g., S3 for TechDocs)

### Security Groups

| SG | Inbound | Outbound |
|---|---|---|
| ALB SG | 80/tcp from 0.0.0.0/0, 443/tcp from 0.0.0.0/0 | All |
| ECS Task SG | 7007/tcp from ALB SG | All (for ECR, Secrets Manager, RDS) |
| RDS SG | 5432/tcp from ECS Task SG | All |

---

## Networking Diagram

```
Security Group Flow:

  Internet
     │
     ▼ :80, :443
  ┌──────────┐
  │  ALB SG  │  ingress: 0.0.0.0/0 :80, :443
  └────┬─────┘  egress:  all
       │
       ▼ :7007
  ┌──────────────┐
  │  ECS Task SG │  ingress: ALB SG :7007 only
  └──────┬───────┘  egress:  all (NAT → ECR, Secrets Manager)
         │
         ▼ :5432
  ┌──────────┐
  │  RDS SG  │  ingress: ECS Task SG :5432 only
  └──────────┘  egress:  all

Route Tables:

  Public subnets:  0.0.0.0/0 → Internet Gateway
  Private subnets: 0.0.0.0/0 → NAT Gateway (in public subnet AZ-a)
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Subnet AZ Distribution

*For any* VPC module instantiation with two availability zones, the module should produce at least two public subnets in distinct AZs and at least two private subnets in distinct AZs.

**Validates: Requirements 2.2, 2.3**

### Property 2: Route Table Correctness

*For any* subnet created by the VPC module, public subnets must have a default route (`0.0.0.0/0`) pointing to the Internet Gateway, and private subnets must have a default route pointing to the NAT Gateway — never to the Internet Gateway directly.

**Validates: Requirements 2.6, 2.7**

### Property 3: RDS Security Group Least Privilege

*For any* ingress rule on the RDS security group, the only permitted source for port 5432 traffic must be the ECS task security group ID — no other CIDR or security group reference is allowed.

**Validates: Requirements 4.4**

### Property 4: ECS Security Group Least Privilege

*For any* ingress rule on the ECS task security group, the only permitted source for port 7007 traffic must be the ALB security group ID — no other CIDR or security group reference is allowed.

**Validates: Requirements 6.6**

### Property 5: Secrets Injection via Secrets Manager

*For any* secret value referenced in the ECS task definition container spec, it must appear in the `secrets` block (referencing a Secrets Manager ARN via `valueFrom`) and not in the `environment` block as a plaintext value.

**Validates: Requirements 5.3, 6.3**

### Property 6: IAM Least Privilege for Secrets Access

*For any* IAM policy statement granting `secretsmanager:GetSecretValue`, the resource must be scoped to the specific secret ARNs required by the Backstage backend — not a wildcard (`*`).

**Validates: Requirements 5.4, 6.9**

### Property 7: Resource Tagging Invariant

*For any* AWS resource created by the Terraform modules, the resource must have both an `Environment` tag and a `Project` tag set to the values of the corresponding input variables.

**Validates: Requirements 9.4**

### Property 8: Valid Terraform Plan

*For any* valid combination of required input variables, running `terraform plan` against the root module must complete without errors, producing a non-empty plan with no unresolved references or type errors.

**Validates: Requirements 9.7**

---

## Error Handling

### Terraform Apply Failures

- **State lock contention**: DynamoDB lock prevents concurrent applies. The second operator receives a lock error with the lock holder's identity. Resolution: wait for the first apply to complete or force-unlock with `terraform force-unlock <lock-id>` after confirming the first operation is not running.
- **Missing required variables**: `github_oauth_client_id` and `github_oauth_client_secret` have no defaults. Terraform will error at plan time with a clear message. These must be provided via `terraform.tfvars` or environment variables (`TF_VAR_*`).
- **ACM certificate not validated**: If `acm_certificate_arn` is provided but the cert is not yet validated in ACM, the ALB HTTPS listener creation will fail. Resolution: ensure the cert is in `ISSUED` state before applying.
- **RDS deletion**: With `deletion_protection = false`, `terraform destroy` will succeed. This is intentional for MVP teardown.

### ECS Task Failures

- **Image pull failure**: ECS task will fail to start if the ECR image tag does not exist. The service will retry. Resolution: push the image before deploying the service, or set `image_tag` to an existing tag.
- **Secret not found**: If a Secrets Manager secret ARN referenced in the task definition does not exist, the task will fail to start with an access error. Resolution: ensure `terraform apply` for the secrets module completes before the ECS module.
- **Health check failures**: ALB removes the task from rotation after 2 consecutive `/healthcheck` failures. ECS will attempt to replace the task. Common causes: misconfigured `POSTGRES_*` env vars, RDS not reachable (check security groups).

### Dependency Ordering

Terraform handles dependency ordering automatically via resource references. The explicit dependency chain is:

```
VPC → (RDS, ECS, ALB in parallel) → ECS service (depends on ALB target group + RDS endpoint)
Secrets → ECS task definition
```

---

## Testing Strategy

### Dual Testing Approach

Both unit/example tests and property-based tests are required. They are complementary:
- Unit/example tests catch concrete misconfiguration (wrong attribute values, missing resources)
- Property tests verify universal invariants across all valid input combinations

### Unit / Example Tests (Terratest)

Use [Terratest](https://terratest.gruntwork.io/) (Go) to validate specific resource attributes after `terraform apply` against a real AWS account (or use `terraform plan` JSON output for plan-time checks).

Key example tests:
- S3 state bucket has versioning enabled and public access blocked
- ECR repository has `image_tag_mutability = "IMMUTABLE"` and `scan_on_push = true`
- RDS instance has `publicly_accessible = false`, `multi_az = false`, `deletion_protection = false`
- ALB has HTTP→HTTPS redirect listener on port 80
- ECS task definition CPU = 512, memory = 1024
- All required outputs are non-empty strings

### Property-Based Tests

Use [Terratest](https://terratest.gruntwork.io/) with table-driven tests in Go, or use [tftest](https://github.com/GoogleCloudPlatform/terraform-python-testing-helper) (Python) with [Hypothesis](https://hypothesis.readthedocs.io/) for property generation.

Each property test must run a minimum of 100 iterations with varied input combinations.

**Tag format**: `Feature: 02-aws-infrastructure, Property {N}: {property_text}`

| Property | Test Description | Library |
|---|---|---|
| P1: Subnet AZ Distribution | Generate random AZ pairs, verify subnet count and AZ uniqueness in plan output | Terratest + table-driven |
| P2: Route Table Correctness | For each subnet in plan, verify default route target matches subnet type | Terratest + plan JSON |
| P3: RDS SG Least Privilege | Parse plan JSON, verify RDS SG ingress rules have no wildcard sources | Terratest + plan JSON |
| P4: ECS SG Least Privilege | Parse plan JSON, verify ECS SG ingress rules reference only ALB SG | Terratest + plan JSON |
| P5: Secrets Injection | Parse task definition JSON, verify all sensitive vars are in `secrets` not `environment` | Terratest + plan JSON |
| P6: IAM Least Privilege | Parse IAM policy JSON, verify no `*` resource on secretsmanager actions | Terratest + plan JSON |
| P7: Resource Tagging | For all resources in plan, verify `Environment` and `Project` tags present | Terratest + plan JSON |
| P8: Valid Plan | For varied input combinations, verify `terraform plan` exits 0 with no errors | Terratest |

### Plan-Time vs Apply-Time

Prefer plan-time tests (parsing `terraform plan -out=plan.tfplan && terraform show -json plan.tfplan`) for CI speed. Reserve apply-time tests for integration validation in a dedicated test AWS account.

---

## `app-config.production.yaml` Changes

The current `app-config.production.yaml` already has the database and auth sections reading from environment variables. The required changes are:

1. **`app.baseUrl` and `backend.baseUrl`**: Change from `http://localhost:7007` to use the ALB DNS name. Since the ALB DNS name is only known after `terraform apply`, this should be set via an environment variable `APP_BASE_URL` injected by ECS, or configured post-apply.

2. **SSL for PostgreSQL**: Uncomment the `ssl` section and add `rejectUnauthorized: false` for RDS (RDS uses a self-signed cert by default at the instance level; full CA verification requires downloading the RDS CA bundle).

3. **`PGSSLMODE`**: Set `PGSSLMODE=require` as a non-sensitive environment variable in the ECS task definition.

Updated sections:

```yaml
app:
  baseUrl: ${APP_BASE_URL}

backend:
  baseUrl: ${APP_BASE_URL}
  listen: ':7007'

  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      ssl:
        rejectUnauthorized: false
```

The `auth.providers.github` section already reads `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET` from environment variables — no change needed there.

The `APP_BASE_URL` environment variable will be set in the ECS task definition as a non-sensitive env var, with its value set to `https://<alb_dns_name>` (or a custom domain if one is configured).
