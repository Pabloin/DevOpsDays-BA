# Requirements Document

## Introduction

Deploy the Backstage developer portal to AWS using Terraform and ECS Fargate. This covers all infrastructure provisioning: networking (VPC), container registry (ECR), container runtime (ECS Fargate), relational database (RDS PostgreSQL), load balancing (ALB), secrets management (Secrets Manager), and remote Terraform state (S3 + DynamoDB). No CI/CD pipeline is in scope — that is covered by spec `03-ci-cd-pipeline`.

## MVP Constraints

This infrastructure is sized for MVP/development use, targeting ~$50–70/month in AWS costs. It is explicitly **not** production-grade. The following constraints apply throughout all requirements:

- ECS Fargate task: 0.5 vCPU / 1 GB RAM, desired count = 1, no auto-scaling
- RDS: `db.t3.micro`, single-AZ, 20 GB gp2 storage, no deletion protection, no Multi-AZ
- NAT Gateway: single NAT Gateway in one AZ (not HA)
- ALB: standard, no WAF
- No deletion protection on any resources

These constraints MUST be reflected in Terraform variable defaults. Upgrading to production sizing is out of scope for this spec.

## Glossary

- **Terraform**: Infrastructure-as-Code tool used to provision and manage AWS resources declaratively.
- **ECS_Fargate**: AWS serverless container runtime; runs Docker containers without managing EC2 instances.
- **ECR**: AWS Elastic Container Registry; stores Docker images for the Backstage backend.
- **RDS**: AWS Relational Database Service; managed PostgreSQL database for Backstage.
- **ALB**: AWS Application Load Balancer; routes HTTP/HTTPS traffic to ECS tasks.
- **Secrets_Manager**: AWS Secrets Manager; stores sensitive configuration values (DB credentials, GitHub OAuth secrets).
- **VPC**: AWS Virtual Private Cloud; isolated network containing all infrastructure resources.
- **State_Backend**: Remote Terraform state stored in S3 with DynamoDB locking.
- **Backstage_Backend**: The Node.js backend container built from `backstage-portal/packages/backend/Dockerfile`.
- **Task_Definition**: ECS configuration describing the container image, CPU, memory, environment variables, and secrets for a Fargate task.
- **Target_Group**: ALB component that routes requests to healthy ECS tasks.

---

## Requirements

### Requirement 1: Terraform State Backend

**User Story:** As a platform engineer, I want Terraform state stored remotely with locking, so that multiple engineers can safely run Terraform without state conflicts.

#### Acceptance Criteria

1. THE Terraform SHALL store state in an S3 bucket with versioning enabled.
2. THE Terraform SHALL use a DynamoDB table for state locking and consistency checking.
3. WHEN two Terraform operations run concurrently, THE State_Backend SHALL prevent simultaneous writes by acquiring a lock before any state mutation.
4. THE Terraform SHALL encrypt the S3 state bucket using server-side encryption (SSE-S3 or SSE-KMS).
5. THE S3 bucket SHALL block all public access.

---

### Requirement 2: VPC and Networking

**User Story:** As a platform engineer, I want a dedicated VPC with public and private subnets, so that the application is network-isolated and follows AWS security best practices.

#### Acceptance Criteria

1. THE Terraform SHALL create a VPC with a configurable CIDR block.
2. THE Terraform SHALL create at least two public subnets across two Availability Zones.
3. THE Terraform SHALL create at least two private subnets across two Availability Zones.
4. THE Terraform SHALL attach an Internet Gateway to the VPC for public subnet egress.
5. THE Terraform SHALL create a single NAT Gateway in one public subnet so that private subnet resources can reach the internet (MVP: single NAT, not HA across AZs).
6. THE Terraform SHALL create route tables associating public subnets with the Internet Gateway and all private subnets with the single NAT Gateway.
7. WHEN a resource is placed in a private subnet, THE VPC SHALL prevent direct inbound internet access to that resource.

---

### Requirement 3: ECR Repository

**User Story:** As a platform engineer, I want an ECR repository for the Backstage backend image, so that Docker images can be stored and pulled by ECS.

#### Acceptance Criteria

1. THE Terraform SHALL create an ECR repository named after the application (parameterized).
2. THE ECR repository SHALL enable image tag immutability to prevent tag overwrites.
3. THE ECR repository SHALL enable image scanning on push to detect known vulnerabilities.
4. THE Terraform SHALL configure a lifecycle policy on the ECR repository to retain only the most recent N images (configurable, default 10).

---

### Requirement 4: RDS PostgreSQL Database

**User Story:** As a platform engineer, I want a managed PostgreSQL database on RDS, so that Backstage has a durable data store.

#### Acceptance Criteria

1. THE Terraform SHALL create an RDS instance running PostgreSQL 16 or later using instance class `db.t3.micro`.
2. THE RDS instance SHALL be placed in private subnets and SHALL NOT be publicly accessible.
3. THE Terraform SHALL create a dedicated DB subnet group spanning the private subnets.
4. THE Terraform SHALL create a security group that allows inbound PostgreSQL traffic (port 5432) only from the ECS task security group.
5. THE RDS instance SHALL have automated backups enabled with a configurable retention period (default 7 days).
6. THE RDS instance SHALL have deletion protection disabled (MVP constraint; enables easy teardown).
7. THE RDS instance SHALL be deployed in a single Availability Zone with no Multi-AZ standby (MVP constraint).
8. THE RDS instance SHALL use 20 GB gp2 storage (MVP constraint).
9. THE Terraform SHALL store the RDS master password in Secrets_Manager and SHALL NOT hard-code it in Terraform state.
10. WHEN the RDS instance is created, THE Terraform SHALL output the RDS endpoint hostname and port.

---

### Requirement 5: Secrets Manager

**User Story:** As a platform engineer, I want application secrets stored in AWS Secrets Manager, so that sensitive values are never embedded in container images or task definitions.

#### Acceptance Criteria

1. THE Terraform SHALL create a Secrets_Manager secret for the RDS master credentials (username and password).
2. THE Terraform SHALL create a Secrets_Manager secret for GitHub OAuth credentials (`AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET`).
3. WHEN an ECS task starts, THE ECS_Fargate SHALL inject secrets from Secrets_Manager as environment variables into the Backstage_Backend container.
4. THE Terraform SHALL grant the ECS task IAM role read access to only the secrets required by the Backstage_Backend.
5. IF a secret value is rotated in Secrets_Manager, THEN THE ECS_Fargate SHALL pick up the new value on the next task restart without requiring a Terraform apply.

---

### Requirement 6: ECS Fargate Cluster and Service

**User Story:** As a platform engineer, I want the Backstage backend running as an ECS Fargate service, so that the application is containerized and requires no EC2 management.

#### Acceptance Criteria

1. THE Terraform SHALL create an ECS cluster for the Backstage application.
2. THE Terraform SHALL create a Task_Definition specifying the Backstage_Backend container image from ECR, with CPU set to 512 units (0.5 vCPU) and memory set to 1024 MB (1 GB) as MVP defaults.
3. THE Task_Definition SHALL reference secrets from Secrets_Manager for `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `AUTH_GITHUB_CLIENT_ID`, and `AUTH_GITHUB_CLIENT_SECRET`.
4. THE Terraform SHALL create an ECS service with a desired task count of 1 and no auto-scaling configured (MVP constraint).
5. THE ECS service SHALL be placed in private subnets.
6. THE Terraform SHALL create a security group for ECS tasks that allows inbound traffic only from the ALB security group on port 7007.
7. THE ECS task security group SHALL allow all outbound traffic (for ECR image pulls, Secrets Manager, and RDS access).
8. THE Terraform SHALL attach the ECS service to the ALB Target_Group.
9. THE Terraform SHALL create an IAM execution role granting ECS the permissions to pull images from ECR and read secrets from Secrets_Manager.
10. THE Terraform SHALL create an IAM task role for the running container with least-privilege permissions.
11. WHEN the ECS service is updated with a new task definition revision, THE ECS_Fargate SHALL perform a rolling deployment replacing the existing single task.

---

### Requirement 7: Application Load Balancer

**User Story:** As a platform engineer, I want an ALB in front of ECS, so that HTTP traffic is routed to the Backstage task and HTTPS termination is handled at the load balancer.

#### Acceptance Criteria

1. THE Terraform SHALL create an ALB in the public subnets (MVP: standard ALB, no WAF).
2. THE Terraform SHALL create a security group for the ALB that allows inbound HTTP (port 80) and HTTPS (port 443) from `0.0.0.0/0`.
3. THE ALB SHALL forward HTTP (port 80) requests to HTTPS (port 443) via a redirect listener rule.
4. THE ALB SHALL have an HTTPS listener on port 443 that forwards traffic to the ECS Target_Group.
5. WHERE an ACM certificate ARN is provided, THE ALB SHALL attach the certificate to the HTTPS listener.
6. THE Terraform SHALL create a Target_Group with health checks against the Backstage health endpoint (`/healthcheck`) on port 7007.
7. WHEN a target fails two consecutive health checks, THE ALB SHALL remove the target from rotation.
8. WHEN a target passes two consecutive health checks, THE ALB SHALL add the target back into rotation.
9. THE Terraform SHALL output the ALB DNS name.

---

### Requirement 8: Production Configuration Update

**User Story:** As a platform engineer, I want `app-config.production.yaml` updated to reference AWS-sourced values, so that the Backstage application reads its configuration correctly when running in ECS.

#### Acceptance Criteria

1. THE `app-config.production.yaml` SHALL set `app.baseUrl` and `backend.baseUrl` to the ALB DNS name (or a configurable domain), not `localhost`.
2. THE `app-config.production.yaml` SHALL configure the database connection to read `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` from environment variables injected by ECS.
3. THE `app-config.production.yaml` SHALL enable SSL for the PostgreSQL connection when `PGSSLMODE` is set.
4. THE `app-config.production.yaml` SHALL configure the GitHub auth provider to read `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET` from environment variables.

---

### Requirement 9: Terraform Module Structure and Parameterization

**User Story:** As a platform engineer, I want Terraform code organized into reusable modules with a single root module, so that the infrastructure is maintainable and all environment-specific values are parameterized.

#### Acceptance Criteria

1. THE Terraform SHALL be organized into modules: `vpc`, `ecr`, `ecs`, `rds`, `alb`, and `secrets`.
2. THE Terraform root module SHALL accept an `aws_region` variable so that all resources are deployed to a single, configurable AWS region.
3. THE Terraform root module SHALL accept an `environment` variable (e.g., `mvp`) used to tag and name all resources.
4. THE Terraform SHALL tag all resources with at minimum `Environment` and `Project` tags.
5. THE Terraform SHALL define all configurable values as input variables with descriptions and MVP-appropriate default values (0.5 vCPU / 1 GB RAM for ECS, `db.t3.micro` / 20 GB gp2 / single-AZ for RDS, single NAT Gateway for VPC).
6. THE Terraform SHALL output at minimum: ALB DNS name, ECR repository URL, RDS endpoint, and ECS cluster name.
7. WHEN `terraform plan` is run against the root module, THE Terraform SHALL produce a valid plan with no errors.
