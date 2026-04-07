# Design: Shared ECS Environments (`12-shared-ecs-environments`)

## Architecture Overview

```
glaciar.org (Route53 hosted zone)
  ├── *.dev.backstage.glaciar.org  → ALB (dev)  → ECS Fargate cluster (dev)
  └── *.prod.backstage.glaciar.org → ALB (prod) → ECS Fargate cluster (prod)

Each ALB has:
  - HTTPS listener (port 443) with wildcard ACM cert
  - Host-based routing rules (one per deployed service)
  - Default 404 rule

Each ECS cluster:
  - Fargate launch type (Spot for dev, On-Demand for prod)
  - One ECS service per scaffolded app
  - Tasks run in private subnets
  - Pull images from ECR (one repo per service)
```

---

## Reuse Strategy

To minimize cost, **reuse the existing Backstage VPC** (`10.0.0.0/16`) rather than creating a new VPC. The shared ECS clusters live in the same VPC but in separate security groups and subnets from the Backstage portal.

If subnets need to be added (e.g., for isolation), extend the existing VPC with new subnet CIDRs. Otherwise reuse existing private/public subnets.

---

## Terraform Module: `shared-ecs-env`

**File**: `terraform/modules/shared-ecs-env/`

```
modules/shared-ecs-env/
  main.tf       — ECS cluster, ALB, ACM cert, SGs, Route53 records
  variables.tf  — environment, vpc_id, subnets, domain, zone_id
  outputs.tf    — cluster_arn, alb_arn, alb_dns_name, listener_arn, sg_id, cert_arn
```

### Key resources per module instance:

| Resource | Name pattern |
|----------|-------------|
| ECS Cluster | `backstage-apps-{env}` |
| ALB | `backstage-apps-{env}-alb` |
| ALB SG | `backstage-apps-{env}-alb-sg` |
| ACM Cert | `*.{env}.glaciar.org` |
| Route53 wildcard | `*.{env}.glaciar.org → ALB alias` |
| ALB HTTPS Listener | Port 443, default action: fixed 404 |

### ALB Listener Rules (added by each service deployment, NOT this module)

When a scaffolded app is deployed, it adds its own ECS service + ALB listener rule:
- Condition: `Host: <service-name>.<env>.glaciar.org`
- Action: forward to the service's target group

This keeps the shared-ecs-env module clean and stateless relative to the services that use it.

---

## Instantiation in `main.tf`

```hcl
module "ecs_env_dev" {
  source             = "./modules/shared-ecs-env"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_name        = "glaciar.org"
  route53_zone_id    = aws_route53_zone.main.zone_id
}

module "ecs_env_prod" {
  source             = "./modules/shared-ecs-env"
  environment        = "prod"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_name        = "glaciar.org"
  route53_zone_id    = aws_route53_zone.main.zone_id
}
```

---

## New Terraform Outputs

```hcl
# Dev environment
output "ecs_dev_cluster_arn"       { value = module.ecs_env_dev.cluster_arn }
output "ecs_dev_alb_listener_arn"  { value = module.ecs_env_dev.alb_listener_arn_https }
output "ecs_dev_alb_sg_id"         { value = module.ecs_env_dev.alb_security_group_id }
output "ecs_dev_wildcard_cert_arn" { value = module.ecs_env_dev.wildcard_cert_arn }

# Prod environment  
output "ecs_prod_cluster_arn"       { value = module.ecs_env_prod.cluster_arn }
output "ecs_prod_alb_listener_arn"  { value = module.ecs_env_prod.alb_listener_arn_https }
output "ecs_prod_alb_sg_id"         { value = module.ecs_env_prod.alb_security_group_id }
output "ecs_prod_wildcard_cert_arn" { value = module.ecs_env_prod.wildcard_cert_arn }
```

---

## Backstage Scaffolder Template: "Deploy ECS Environment"

**File**: `backstage-portal/templates/ecs-environment/template.yaml`

### Steps:

1. **Form** — user picks: `environment` (dev | prod), `owner`
2. **`fetch:template`** — generate a `catalog-info.yaml` for the Resource entity
3. **`github:actions:dispatch`** — trigger a GitHub Actions workflow (`provision-ecs-env.yml`) passing `environment` as input
4. **`publish:github`** — push catalog-info to a repo (`ecs-environments` in `mvp-glaciar-org`)
5. **`catalog:register`** — register the Resource in Backstage

### Catalog entity registered:
```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: ecs-env-dev          # or ecs-env-prod
  annotations:
    backstage.io/managed-by-location: ...
spec:
  type: aws-ecs-cluster
  owner: group:default/<owner>
  system: glaciar-platform
```

### GitHub Actions workflow: `provision-ecs-env.yml`

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, prod]

jobs:
  provision:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      - uses: hashicorp/setup-terraform@v3
      - run: |
          cd terraform
          terraform init
          terraform apply -auto-approve \
            -target=module.ecs_env_${{ inputs.environment }}
```

---

## Service URL Pattern

When a scaffolded app (e.g., AI assistant named `demo-ai`) is deployed to dev:
- URL: `https://demo-ai.dev.glaciar.org`
- ALB rule: host-header = `demo-ai.dev.glaciar.org` → target group for that ECS service

---

## What Is NOT in This Spec

- Deploying individual scaffolded services to these clusters (that's spec 13)
- Updating the AI template to add an ECS deploy step (that's spec 13)
- ECR repos per service (provisioned at service deploy time, not environment creation time)
