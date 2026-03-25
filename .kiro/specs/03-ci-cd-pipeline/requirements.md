# Requirements Document

> **WIP — To be detailed after `02-aws-infrastructure` is complete.**

## Introduction

Set up a CI/CD pipeline using GitHub Actions with OIDC to build and deploy the Backstage backend to AWS ECS Fargate. No long-lived AWS credentials are stored in GitHub secrets.

## Scope

- GitHub Actions workflow triggered on push to `main`
- OIDC-based AWS authentication (no static access keys)
- Build and push Docker image to ECR
- Deploy new task definition revision to ECS Fargate (rolling update)
- Environment-specific deployments (production)

## TBD

Full requirements, acceptance criteria, and tasks will be written once `02-aws-infrastructure` is merged and the Terraform outputs (ECR URL, ECS cluster/service names) are known.
