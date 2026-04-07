# Requirements: Deploy Scaffolded Service to ECS (`13-deploy-service-to-ecs`)

## Overview

When a user scaffolds the AI Ops Assistant (or any future service template), they can choose to deploy it directly to one of the shared ECS environments (`dev.backstage.glaciar.org` or `prod.backstage.glaciar.org`). The scaffolded service runs as an ECS Fargate task behind the shared ALB, reachable at `<service-name>.<env>.backstage.glaciar.org`.

This spec covers:
1. A reusable Terraform module (`deploy-service`) that provisions everything needed for one service in one environment
2. A GitHub Actions workflow (`deploy-service.yml`) that builds and deploys a service image
3. Updates to the AI Ops Assistant template to add an optional ECS deploy step
4. The Dockerfile for the AI Ops Assistant app (frontend + backend in one container)

---

## Functional Requirements

### 1. Terraform Module `deploy-service`

**1.1** Create `terraform/modules/deploy-service/` that provisions all AWS resources for one service instance:
- ECR repository for the service image
- ECS task definition (Fargate, Linux/ARM64 or X86_64)
- ECS service attached to the shared cluster
- ALB target group
- ALB listener rule: `host-header = <service-name>.<env>.backstage.glaciar.org` → target group
- ECS task security group (ingress from shared ALB SG, egress all)
- IAM task execution role + task role (with Bedrock permissions for AI assistant)

**1.2** Module inputs:
- `service_name` — e.g. `my-ai-assistant`
- `environment` — `dev` or `prod`
- `vpc_id`
- `private_subnet_ids` — ECS tasks run in private subnets
- `cluster_arn` — from `module.ecs_env_{env}.cluster_arn`
- `alb_listener_arn` — from `module.ecs_env_{env}.alb_listener_arn_https`
- `alb_security_group_id` — from `module.ecs_env_{env}.alb_security_group_id`
- `base_domain` — `backstage.glaciar.org`
- `bedrock_model_id` — Bedrock model ID (e.g. `anthropic.claude-3-haiku-20240307-v1:0`)
- `aws_region` — default `us-east-1`
- `container_port` — default `3001` (backend serves frontend too in production)
- `cpu` — default `512`
- `memory` — default `1024`
- `image_tag` — default `latest`
- `project`

**1.3** Module outputs:
- `ecr_repository_url`
- `service_url` — `https://<service-name>.<env>.backstage.glaciar.org`
- `ecs_service_name`
- `task_execution_role_arn`
- `task_role_arn`

**1.4** The ALB listener rule must use a priority that avoids conflicts. Use a hash of `service_name + environment` to generate a stable priority in the range 1–50000.

**1.5** The ECS task role must have permission to call `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream` on all models (`*`) in `us-east-1`.

---

### 2. Production Dockerfile for AI Ops Assistant

**2.1** The generated app needs a single-container production image that serves both frontend and backend.

**2.2** The Dockerfile (added to the `content/` directory of the AI template) must:
- Stage 1: build the React frontend with `vite build`
- Stage 2: copy built frontend into the Node.js backend under `public/`
- Backend serves static files from `public/` at `/`
- Backend API remains at `/api/*`
- Single exposed port: `3001`

**2.3** Add `express.static('public')` to `backend/index.js` template so the backend serves the built frontend.

---

### 3. GitHub Actions Workflow `deploy-service.yml`

**3.1** Create `.github/workflows/deploy-service.yml` triggered by `workflow_dispatch` with inputs:
- `service_name` — name of the service repo in `mvp-glaciar-org`
- `environment` — `dev` or `prod`
- `bedrock_model_id` — model to use
- `image_tag` — default `latest`

**3.2** Workflow steps:
1. Checkout the **service repo** (`mvp-glaciar-org/<service_name>`) — not this repo
2. Configure AWS credentials via OIDC (`TERRAFORM_ROLE_ARN`)
3. Login to ECR
4. Build Docker image from the service repo's Dockerfile
5. Run `terraform apply -target=module.service_<service_name>_<env>` in this repo to provision AWS resources (creates ECR repo, ECS service, ALB rule)
6. Push image to ECR
7. Force new ECS deployment

**3.3** The workflow must be idempotent — running it twice for the same service/env is safe.

---

### 4. AI Ops Assistant Template Updates

**4.1** Add a new optional form step to the AI Ops Assistant template: **"Deploy to ECS"**
- `deploy_to_ecs` — boolean, default `false`
- `ecs_environment` — select: dev | prod (shown only if `deploy_to_ecs = true`)

**4.2** Add a conditional step `github:actions:dispatch` that triggers `deploy-service.yml` when `deploy_to_ecs = true`, passing `service_name`, `environment`, `bedrock_model_id`.

**4.3** Update `catalog-info.yaml` template to include the ECS service URL when deployed:
- Link: `https://<service-name>.<env>.backstage.glaciar.org`

**4.4** The deploy step is optional — the template still works without ECS deploy (docker-compose local dev flow unchanged).

---

### 5. Terraform Root Module

**5.1** Services are NOT pre-declared in `terraform/main.tf` — each service is provisioned on-demand by the `deploy-service.yml` workflow using `-target`.

**5.2** The workflow uses `terraform apply` with a dynamically generated module block written to a file `terraform/services.tf` (gitignored is NOT an option — it must be committed). Instead, the workflow:
- Checks out the DevOpsDays-BA repo
- Appends a module block for the new service to `terraform/services.tf`
- Commits and pushes `services.tf`
- Runs `terraform apply -target=module.svc_<service>_<env>`

**5.3** `terraform/services.tf` starts empty (just a comment) and accumulates service module blocks over time.

---

## Non-Functional Requirements

**NFR-1** The frontend + backend must run in a single container to keep ECS costs low (one task per service).

**NFR-2** The Bedrock API calls use the ECS task role (IAM role attached to the task) — no hardcoded credentials.

**NFR-3** ECS tasks run in private subnets; traffic enters only via the shared ALB.

**NFR-4** The module must not hardcode account IDs or region — use data sources.
