# Architecture

## Overview

Backstage runs as a single container on AWS ECS Fargate in a private VPC, fronted by an Application Load Balancer with HTTPS. All infrastructure is managed with Terraform.

## AWS Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  Route 53 (backstage.glaciar.org)                   │
└────────────────────┬────────────────────────────────┘
                     │ A alias
                     ▼
┌─────────────────────────────────────────────────────┐
│  Application Load Balancer (public subnets)         │
│  HTTPS :443 → HTTP :7007  |  HTTP :80 → redirect    │
│  ACM Certificate (DNS validated)                    │
└────────────────────┬────────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │   Private Subnets   │
          │                     │
          │  ┌───────────────┐  │
          │  │  ECS Fargate  │  │
          │  │  (Backstage)  │  │
          │  │  port 7007    │  │
          │  └───────┬───────┘  │
          │          │          │
          │  ┌───────▼───────┐  │
          │  │  RDS Postgres │  │
          │  │  port 5432    │  │
          │  └───────────────┘  │
          │                     │
          │  NAT Gateway ──────►│──► github.com (OAuth)
          └─────────────────────┘
```

## Components

### Networking (VPC)
- **VPC**: `10.0.0.0/16` across 2 AZs
- **Public subnets**: ALB and NAT Gateway
- **Private subnets**: ECS tasks and RDS
- **NAT Gateway**: single AZ (~$16/month) — required for GitHub OAuth token exchange and outbound API calls
- **Internet Gateway**: public internet access for ALB

### Compute (ECS Fargate)
- Single task running the Backstage backend
- Image stored in ECR (`backstage-mvp`)
- Secrets injected from AWS Secrets Manager at startup
- CloudWatch Logs for observability

### Database (RDS PostgreSQL)
- `db.t3.micro` in private subnets
- Credentials stored in Secrets Manager
- SSL required

### DNS & TLS
- Route 53 hosted zone for `backstage.glaciar.org`
- ACM certificate with DNS validation
- NS records delegated from parent `glaciar.org` zone

## Secrets

| Secret | Stored in | Injected as |
|---|---|---|
| GitHub OAuth Client ID | Secrets Manager | `AUTH_GITHUB_CLIENT_ID` |
| GitHub OAuth Client Secret | Secrets Manager | `AUTH_GITHUB_CLIENT_SECRET` |
| GitHub PAT (scaffolder) | Secrets Manager | `GITHUB_TOKEN` |
| RDS host/port/user/password | Secrets Manager | `POSTGRES_*` |

## Authentication flows

### User login (GitHub OAuth)
```
Browser → /api/auth/github/start → 302 → github.com
github.com → /api/auth/github/handler/frame?code=XXX
ECS backend → github.com/login/oauth/access_token (via NAT)
ECS backend → session created → browser redirected
```

### CI/CD (GitHub Actions OIDC)
```
GitHub Actions → sts:AssumeRoleWithWebIdentity (OIDC, no stored secrets)
→ ECR push (docker image)
→ ECS update-service (rolling deploy)
```

Note: these are **two separate authentication mechanisms**. OIDC is only for the CI/CD pipeline. The Backstage backend uses a GitHub PAT to call the GitHub API (e.g., creating repos via the scaffolder).

## Cost estimate (~$60/month)

| Resource | Cost |
|---|---|
| ECS Fargate (0.5 vCPU, 1GB) | ~$15/month |
| RDS PostgreSQL db.t3.micro | ~$15/month |
| ALB | ~$18/month |
| NAT Gateway (1 AZ) | ~$16/month |
| ECR, Route 53, ACM, CloudWatch | ~$5/month |
