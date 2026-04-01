# Implementation Plan: CI/CD Pipeline

## Overview

Implement the GitHub Actions OIDC-based CI/CD pipeline and its supporting Terraform infrastructure.

## Status: Complete ✓

All Terraform infrastructure was deployed as part of spec `02-aws-infrastructure` and `bcc2aaa`.
The GitHub Actions workflow was created on `feature/03-ci-cd-pipeline`.

---

## Tasks

- [x] 1. Add `ecs_cluster_arn` and `ecs_service_arn` outputs to the ECS module
  - Added `ecs_cluster_arn` and `ecs_service_arn` to `terraform/modules/ecs/outputs.tf`
  - _Requirements: 2.4, 8.1_

- [x] 2. Create the Terraform OIDC module (`terraform/modules/oidc/`)
  - [x] 2.1 `terraform/modules/oidc/variables.tf` — all input variables declared
  - [x] 2.2 `terraform/modules/oidc/main.tf` — OIDC provider, GitHub Actions role, inline policy
    - Trust policy restricts to `repo:Pabloin/DevOpsDays-BA:ref:refs/heads/main`
    - Least-privilege permissions: ECRAuth, ECRPush, ECSRegisterTaskDef, ECSDeployment, PassExecutionRole
  - [x] 2.6 `terraform/modules/oidc/outputs.tf` — exports `role_arn`
  - _Requirements: 1.2–1.6, 2.1–2.6, 8.1–8.3_

- [x] 3. Wire OIDC module into root Terraform
  - [x] `module "oidc"` block in `terraform/main.tf`
  - [x] `github_repository` variable in `terraform/variables.tf`
  - [x] `github_actions_role_arn` output in `terraform/outputs.tf`
  - Role ARN: `arn:aws:iam::703671890483:role/backstage-mvp-github-actions-role`
  - _Requirements: 8.4, 8.5_

- [x] 4. Create GitHub Actions workflow (`.github/workflows/deploy.yml`)
  - Trigger: push to `main` only
  - OIDC auth via `AWS_ROLE_ARN` secret — no long-lived credentials
  - Env vars hardcoded (non-secret): region, ECR repo, ECS cluster/service, task definition family
  - Steps: checkout → OIDC auth → ECR login → Node 22 setup → yarn install/tsc/build → docker build+push → ECS deploy+wait
  - Task definition name fixed to `backstage-mvp-backstage` (not service name)
  - All third-party actions pinned to commit SHAs
  - _Requirements: 1.1, 3.1–3.4, 4.1–4.4, 5.1–5.3, 6.1–6.6, 7.1–7.4_

## One Manual Step Required

After merging this branch, add one GitHub repository secret:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::703671890483:role/backstage-mvp-github-actions-role` |

All other values (region, cluster, service names) are hardcoded in the workflow — no other secrets needed.

## Notes

- Tasks marked `*` (property-based tests) are skipped for MVP
- ECR tags are now **mutable** — the pipeline always pushes `:<git-sha>` + `:latest`
- `aws ecs wait services-stable` blocks the workflow until the new task is healthy (~2–3 min)
