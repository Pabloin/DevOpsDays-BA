# Implementation Plan: Shared ECS Environments (`12-shared-ecs-environments`)

## Tasks

- [x] 1. Terraform module `shared-ecs-env`
  - [x] 1.1 Create `terraform/modules/shared-ecs-env/variables.tf`
  - [x] 1.2 Create `terraform/modules/shared-ecs-env/main.tf` (ECS cluster, ALB, ACM cert, Route53 zone + wildcard record)
  - [x] 1.3 Create `terraform/modules/shared-ecs-env/outputs.tf`
  - _Requirements: 1.1–1.5, 2.1–2.2, 3.1–3.3_

- [x] 2. Instantiate dev + prod in `terraform/main.tf`
  - [x] 2.1 Add `module "ecs_env_dev"` block
  - [x] 2.2 Add `module "ecs_env_prod"` block
  - [x] 2.3 Add new outputs to `terraform/outputs.tf` (cluster_name, alb_listener_arn, alb_sg_id, nameservers)
  - [x] 2.4 Add `terraform_provisioner` IAM role with AdministratorAccess for OIDC workflow_dispatch
  - [x] 2.5 Add `oidc_provider_arn` output to OIDC module
  - _Requirements: 2.3_

- [x] 3. GitHub Actions workflow `provision-ecs-env.yml`
  - [x] 3.1 Create `.github/workflows/provision-ecs-env.yml` with `workflow_dispatch` trigger (dev | prod)
  - [x] 3.2 Steps: checkout → OIDC (TERRAFORM_ROLE_ARN) → setup Terraform → plan → apply -target
  - _Requirements: 4.3_

- [x] 4. Backstage scaffolder template
  - [x] 4.1 Create `backstage-portal/examples/template/ecs-environment/template.yaml`
  - [x] 4.2 Create `backstage-portal/examples/template/ecs-environment/content/catalog-info.yaml`
  - [x] 4.3 Register template in `app-config.production.yaml` and `app-config.yaml`
  - _Requirements: 4.1–4.5_

- [ ] 5. Apply Terraform and verify
  - [ ] 5.1 Run `terraform plan` targeting both ecs_env modules, review output
  - [ ] 5.2 Run `terraform apply` for dev environment first
  - [ ] 5.3 Verify `*.dev.backstage.glaciar.org` wildcard DNS resolves to dev ALB
  - [ ] 5.4 Run `terraform apply` for prod environment
  - [ ] 5.5 Verify `*.prod.backstage.glaciar.org` wildcard DNS resolves to prod ALB
  - _Requirements: 1.1–1.5, 3.1–3.3_

- [ ] 6. Test Backstage template
  - [ ] 6.1 Deploy updated Backstage (with new template registered)
  - [ ] 6.2 Use template to provision dev environment via Backstage UI
  - [ ] 6.3 Verify GitHub Actions workflow runs and Terraform applies successfully
  - [ ] 6.4 Verify `ecs-env-dev` Resource appears in Backstage catalog
  - _Requirements: 4.1–4.5_

- [ ] 7. Commit, push, and deploy
  - [ ] 7.1 Create branch `feature/12-shared-ecs-environments`
  - [ ] 7.2 Commit Terraform module, workflow, and Backstage template
  - [ ] 7.3 Open PR and share URL
  - [ ] 7.4 Merge to main — CI/CD deploys updated Backstage

## Out of Scope (see spec 13)
- Deploying individual scaffolded services (AI template, etc.) to these clusters
- Adding ECS deploy step to the AI Ops Assistant template (spec 08 update)
- Per-service ECR repos, ECS service definitions, and ALB listener rules
