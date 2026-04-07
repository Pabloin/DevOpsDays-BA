# Requirements: Shared ECS Environments for Scaffolded Services (`12-shared-ecs-environments`)

## Overview

Create a shared ECS deployment platform (dev and prod) where all Backstage-scaffolded services can be deployed. This is completely separate from the Backstage portal's own ECS infrastructure. Each environment gets its own ALB and Route53 subdomain so that scaffolded apps are reachable at `<service>.dev.glaciar.org` or `<service>.prod.glaciar.org`.

---

## Functional Requirements

### 1. Shared ECS Environment Infrastructure

**1.1** Each environment (dev, prod) must have:
- A dedicated ECS Fargate cluster
- An Application Load Balancer (ALB) with HTTPS (ACM certificate)
- A wildcard ACM certificate for `*.dev.backstage.glaciar.org` and `*.prod.backstage.glaciar.org`
- A Route53 hosted zone or records under `glaciar.org` for routing
- A shared VPC (or reuse the existing Backstage VPC for cost savings)

**1.2** The dev environment must serve traffic at `*.dev.backstage.glaciar.org` (e.g., `my-ai-app.dev.glaciar.org`).

**1.3** The prod environment must serve traffic at `*.prod.backstage.glaciar.org` (e.g., `my-ai-app.prod.glaciar.org`).

**1.4** Each environment must support multiple independent services running simultaneously as separate ECS services/tasks behind the shared ALB, using ALB host-based routing rules.

**1.5** The Terraform module must be parameterized by `environment` (dev | prod) so the same module provisions both.

---

### 2. Terraform Module

**2.1** Create a reusable Terraform module at `terraform/modules/shared-ecs-env/` with inputs:
- `environment` — "dev" or "prod"
- `vpc_id` — VPC to deploy into
- `public_subnet_ids` — for ALB
- `private_subnet_ids` — for ECS tasks
- `domain_name` — base domain (e.g., `glaciar.org`)
- `route53_zone_id` — hosted zone ID

**2.2** Module outputs:
- `cluster_arn` — ECS cluster ARN
- `alb_arn` — ALB ARN
- `alb_dns_name` — ALB DNS name
- `alb_listener_arn_https` — HTTPS listener ARN (for service ECS rules to attach to)
- `alb_security_group_id` — for ECS task SG ingress rules
- `wildcard_cert_arn` — ACM certificate ARN

**2.3** Instantiate both environments in `terraform/main.tf`:
```hcl
module "ecs_env_dev"  { source = "./modules/shared-ecs-env"; environment = "dev";  ... }
module "ecs_env_prod" { source = "./modules/shared-ecs-env"; environment = "prod"; ... }
```

---

### 3. Route53

**3.1** Each environment's ALB must have a wildcard DNS alias record:
- `*.dev.backstage.glaciar.org`  → dev ALB
- `*.prod.backstage.glaciar.org` → prod ALB

**3.2** The wildcard record must be an alias A record in the existing `glaciar.org` Route53 hosted zone.

**3.3** ACM certificates must validate via DNS and cover `*.dev.backstage.glaciar.org` / `*.prod.backstage.glaciar.org`.

---

### 4. Backstage Scaffolder Template

**4.1** Create a new Backstage template: **"Deploy ECS Environment"** that provisions one shared ECS environment (dev or prod).

**4.2** Template form inputs:
- `environment` — select: dev | prod
- `owner` — Backstage owner group

**4.3** The template must trigger a GitHub Actions workflow that runs `terraform apply` for the selected environment module.

**4.4** After provisioning, the template registers the environment as a `Resource` entity in the Backstage catalog (kind: Resource, type: aws-ecs-cluster).

**4.5** The template must be idempotent — running it twice for the same environment should not fail (Terraform handles this naturally).

---

### 5. Future Integration (out of scope for this spec, tracked in spec 13)

**5.1** The AI Ops Assistant template (spec 08) will be updated to add a deploy step that asks the user which environment (dev | prod) to deploy to.

**5.2** The scaffolded service will be deployed as an ECS service in the chosen cluster, with an ALB listener rule for `<service-name>.<env>.glaciar.org`.

---

## Non-Functional Requirements

**NFR-1** Cost: dev cluster should use Fargate Spot where possible to reduce cost.

**NFR-2** Security: ECS tasks must run in private subnets; ALB in public subnets.

**NFR-3** The two environments (dev/prod) must be completely independent — a failing task in dev must not affect prod.

**NFR-4** No NAT Gateway — use VPC endpoints (matching existing cost optimization strategy).
