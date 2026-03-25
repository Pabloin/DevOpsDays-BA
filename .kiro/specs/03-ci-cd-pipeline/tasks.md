# Implementation Plan: CI/CD Pipeline

## Overview

Implement the GitHub Actions OIDC-based CI/CD pipeline and its supporting Terraform infrastructure. Tasks proceed in dependency order: ECS module outputs first, then the OIDC Terraform module, then root wiring, then the workflow file.

## Tasks

- [x] 1. Add `ecs_cluster_arn` and `ecs_service_arn` outputs to the ECS module
  - In `terraform/modules/ecs/outputs.tf`, add two new outputs:
    - `ecs_cluster_arn` — value `aws_ecs_cluster.main.arn`
    - `ecs_service_arn` — value `aws_ecs_service.main.arn`
  - These are required by the OIDC module to scope IAM permissions
  - _Requirements: 2.4, 8.1_

  - [ ]* 1.1 Write structural test asserting both outputs are declared in `outputs.tf`
    - Parse HCL or grep for `output "ecs_cluster_arn"` and `output "ecs_service_arn"`
    - _Requirements: 2.4_

- [x] 2. Create the Terraform OIDC module (`terraform/modules/oidc/`)
  - [x] 2.1 Create `terraform/modules/oidc/variables.tf`
    - Declare variables: `github_repository` (string), `ecr_repository_arn` (string), `ecs_cluster_arn` (string), `ecs_service_arn` (string), `ecs_execution_role_arn` (string), `environment` (string), `project` (string)
    - _Requirements: 8.4_

  - [x] 2.2 Create `terraform/modules/oidc/main.tf`
    - Define `aws_iam_openid_connect_provider.github` with issuer `https://token.actions.githubusercontent.com` and the correct thumbprint
    - Define `aws_iam_role.github_actions` with a trust policy that allows `sts:AssumeRoleWithWebIdentity` from the OIDC provider, with `StringEquals` conditions on `aud` (`sts.amazonaws.com`) and `sub` (`repo:<var.github_repository>:ref:refs/heads/main`)
    - Define `aws_iam_role_policy.github_actions` as an inline policy with the least-privilege statements from the design: `ECRAuth` (`ecr:GetAuthorizationToken`, resource `*`), `ECRPush` (scoped to `var.ecr_repository_arn`), `ECSRegisterTaskDef` (`ecs:RegisterTaskDefinition`, resource `*`), `ECSDeployment` (scoped to `var.ecs_cluster_arn` and `var.ecs_service_arn`), `PassExecutionRole` (`iam:PassRole`, scoped to `var.ecs_execution_role_arn`)
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 8.1, 8.2, 8.3_

  - [ ]* 2.3 Write property test for Property 2: Trust policy restricts assumption to repo and main branch
    - Generator: random GitHub repository strings in `org/repo` format
    - Assertion: rendered `sub` condition equals `repo:<input>:ref:refs/heads/main`; action is `sts:AssumeRoleWithWebIdentity`
    - **Property 2: Trust policy restricts assumption to repo and main branch**
    - **Validates: Requirements 1.4, 1.5**

  - [ ]* 2.4 Write property test for Property 3: Permissions policy contains no wildcard actions
    - Generator: random sets of valid ARN inputs
    - Assertion: no statement in the generated policy has `Action: "*"` or `Action: ["*"]`
    - **Property 3: Permissions policy contains no wildcard actions**
    - **Validates: Requirements 2.6**

  - [ ]* 2.5 Write property test for Property 4: Permissions policy scopes all non-global actions to specific ARNs
    - Generator: random valid ARN strings for ECR repo, ECS cluster, ECS service, execution role
    - Assertion: ECR push actions resource = `ecr_repository_arn`; ECS actions resources ⊆ `{ecs_cluster_arn, ecs_service_arn}`; PassRole resource = `ecs_execution_role_arn`
    - **Property 4: Permissions policy scopes all non-global actions to specific ARNs**
    - **Validates: Requirements 2.2, 2.4, 2.5**

  - [x] 2.6 Create `terraform/modules/oidc/outputs.tf`
    - Export `role_arn` — value `aws_iam_role.github_actions.arn`
    - _Requirements: 8.5_

- [x] 3. Checkpoint — run `terraform validate` against the OIDC module
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Wire the OIDC module into root Terraform
  - [x] 4.1 Add `module "oidc"` block to `terraform/main.tf`
    - Source: `./modules/oidc`
    - Pass: `github_repository` (new root variable), `ecr_repository_arn` ← `module.ecr.repository_arn`, `ecs_cluster_arn` ← `module.ecs.ecs_cluster_arn`, `ecs_service_arn` ← `module.ecs.ecs_service_arn`, `ecs_execution_role_arn` ← `module.ecs.ecs_task_execution_role_arn`, `environment`, `project`
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 4.2 Add `github_repository` input variable to `terraform/variables.tf`
    - Type: `string`, description: `"GitHub repository in org/repo format, used to scope the OIDC trust policy"`
    - _Requirements: 8.4_

  - [x] 4.3 Add `github_actions_role_arn` output to `terraform/outputs.tf`
    - Value: `module.oidc.role_arn`
    - Description: `"ARN of the GitHub Actions IAM role — store as AWS_ROLE_ARN GitHub secret"`
    - _Requirements: 8.5_

- [x] 5. Create the GitHub Actions workflow (`.github/workflows/deploy.yml`)
  - [x] 5.1 Create `.github/workflows/deploy.yml` with trigger, permissions, and env block
    - Trigger: `push` to `main` only
    - Job `deploy` on `ubuntu-latest`
    - Job-level permissions: `id-token: write`, `contents: read`
    - `env` block: `AWS_REGION`, `ECR_REPOSITORY`, `ECS_CLUSTER`, `ECS_SERVICE` from secrets; `IMAGE_TAG: ${{ github.sha }}`
    - _Requirements: 3.1, 3.2, 3.3, 7.2, 7.4_

  - [x] 5.2 Add checkout and AWS credential steps
    - `actions/checkout` pinned to a commit SHA
    - `aws-actions/configure-aws-credentials` pinned to a commit SHA, with `role-to-assume: ${{ secrets.AWS_ROLE_ARN }}`, `aws-region`, and no `aws-access-key-id` / `aws-secret-access-key` inputs
    - _Requirements: 1.1, 7.1_

  - [x] 5.3 Add ECR login and Node.js setup steps
    - `aws-actions/amazon-ecr-login` pinned to a commit SHA; capture the `registry` output
    - `actions/setup-node` pinned to a commit SHA with `node-version: '22'`
    - _Requirements: 5.1, 7.1_

  - [x] 5.4 Add build steps (yarn install, tsc, build:backend)
    - Working directory: `backstage-portal/`
    - Steps: `yarn install --immutable`, `yarn tsc`, `yarn build:backend` in that order
    - _Requirements: 4.1_

  - [x] 5.5 Add Docker build and push steps
    - Build: `docker build -f packages/backend/Dockerfile -t <ECR_URI>:$IMAGE_TAG -t <ECR_URI>:latest .` from `backstage-portal/` context
    - Push both `:<IMAGE_TAG>` and `:latest` tags
    - Construct `ECR_IMAGE` as `${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/${{ env.ECR_REPOSITORY }}`
    - _Requirements: 3.4, 4.2, 4.3, 4.4, 5.2, 5.3_

  - [x] 5.6 Add ECS deploy steps (describe → render → register → update → wait)
    - `aws ecs describe-task-definition` to capture current task def JSON
    - `jq` inline to strip AWS-managed fields and replace `containerDefinitions[0].image` with the new ECR URI
    - `aws ecs register-task-definition --cli-input-json` to create new revision
    - `aws ecs update-service` with the new task definition ARN
    - `aws ecs wait services-stable` to block until healthy
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [ ]* 5.7 Write property test for Property 1: OIDC authentication excludes long-lived credentials
    - Parse the workflow YAML; assert `configure-aws-credentials` step has `role-to-assume` and lacks `aws-access-key-id` / `aws-secret-access-key`
    - **Property 1: OIDC authentication excludes long-lived credentials**
    - **Validates: Requirements 1.1**

  - [ ]* 5.8 Write property test for Property 5: ECR image URI construction is correct for all inputs
    - Generator: random 12-digit account IDs, region strings, repo names, 40-char hex SHAs
    - Assertion: constructed URI matches `^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[^:]+:[a-f0-9]{40}$`
    - **Property 5: ECR image URI construction is correct for all inputs**
    - **Validates: Requirements 3.4**

  - [ ]* 5.9 Write property test for Property 6: Task definition image replacement preserves all other fields
    - Generator: random ECS task definition JSON with a `backstage` container; random ECR image URIs
    - Assertion: after jq transform, `containerDefinitions[0].image` equals new URI; all other container fields unchanged; metadata fields absent
    - **Property 6: Task definition image replacement preserves all other fields**
    - **Validates: Requirements 6.2**

  - [ ]* 5.10 Write property test for Property 7: All third-party GitHub Actions are pinned to commit SHAs
    - Parse the workflow YAML; for every non-local `uses:` value assert it matches `^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+@[0-9a-f]{40}$`
    - **Property 7: All third-party GitHub Actions are pinned to commit SHAs**
    - **Validates: Requirements 7.1**

- [x] 6. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- All third-party `uses:` references must be pinned to 40-character commit SHAs, not mutable tags
- The `github_repository` variable must be added to `terraform.tfvars.example` alongside the new root variable
- After `terraform apply`, copy the `github_actions_role_arn` output value into the `AWS_ROLE_ARN` GitHub repository secret
