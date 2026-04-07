# Implementation Plan: Deploy Scaffolded Service to ECS (`13-deploy-service-to-ecs`)

## Tasks

- [ ] 1. Terraform module `deploy-service`
  - [ ] 1.1 Create `terraform/modules/deploy-service/variables.tf`
  - [ ] 1.2 Create `terraform/modules/deploy-service/main.tf`:
    - [ ] ECR repository (`<service_name>-<env>`)
    - [ ] ECS task execution role + task role (with Bedrock permissions)
    - [ ] ECS task definition (Fargate, single container, port 3001)
    - [ ] ECS service in shared cluster
    - [ ] ALB target group (health check on `/api/health` or `/`)
    - [ ] ALB listener rule (host-header → target group, stable priority)
    - [ ] Task security group (ingress from ALB SG on container port, egress all)
  - [ ] 1.3 Create `terraform/modules/deploy-service/outputs.tf`
  - _Requirements: 1.1–1.5_

- [ ] 2. `terraform/services.tf` seed file
  - [ ] 2.1 Create `terraform/services.tf` with header comment only
  - _Requirements: 5.3_

- [ ] 3. Production Dockerfile for AI Ops Assistant template
  - [ ] 3.1 Add `Dockerfile` to `backstage-portal/examples/template/ai-ops-assistant/content/`
    - [ ] Stage 1: build React frontend (`vite build`)
    - [ ] Stage 2: Node.js backend serves built frontend from `public/`
  - [ ] 3.2 Update `backend/index.js` template to add `express.static('public')` for production serving
  - [ ] 3.3 Add `/api/health` endpoint to `backend/index.js` template (returns 200, used by ALB health check)
  - _Requirements: 2.1–2.3_

- [ ] 4. GitHub Actions workflow `deploy-service.yml`
  - [ ] 4.1 Create `.github/workflows/deploy-service.yml` with `workflow_dispatch` inputs
  - [ ] 4.2 Steps: checkout infra + service repos → AWS OIDC → ECR login → append module to services.tf (idempotent) → terraform apply -target → build + push image → force ECS deployment
  - _Requirements: 3.1–3.3_

- [ ] 5. Update AI Ops Assistant template
  - [ ] 5.1 Add "Deploy to ECS" optional form step to `template.yaml`
  - [ ] 5.2 Add conditional `github:actions:dispatch` step for `deploy-service.yml`
  - [ ] 5.3 Update `catalog-info.yaml` template to include ECS service URL link (conditional on deployment)
  - _Requirements: 4.1–4.4_

- [ ] 6. Test end-to-end
  - [ ] 6.1 Scaffold a new AI assistant with "Deploy to ECS" checked, environment = dev
  - [ ] 6.2 Verify `deploy-service.yml` workflow runs successfully
  - [ ] 6.3 Verify ECS service is running in `backstage-apps-dev` cluster
  - [ ] 6.4 Verify app is reachable at `https://<service-name>.dev.backstage.glaciar.org`
  - [ ] 6.5 Verify Bedrock calls work (IAM task role has correct permissions)

- [ ] 7. Commit, push, and deploy
  - [ ] 7.1 Create branch `feature/13-deploy-service-to-ecs`
  - [ ] 7.2 Commit all changes
  - [ ] 7.3 Open PR and share URL
  - [ ] 7.4 Merge to main — CI/CD deploys updated Backstage

## Out of Scope
- Service teardown / undeploy
- Other template types using the deploy-service module
- Custom env vars, secrets, or database connections per service
