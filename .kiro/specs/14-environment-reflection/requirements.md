# Requirements: Environment Reflection & Testing (`14-environment-reflection`)

## Goal

Validate that the DevOpsDays BA platform (specs 12–13) is fully functional by running structured reflection tests against the deployed infrastructure. This is not a feature spec, but a **testing & validation spec** to confirm:

1. GitHub organization (`mvp-glaciar-org`) is accessible and configured
2. Shared ECS environments (dev/prod) are provisioned and reachable
3. Terraform modules work correctly
4. The `deploy-service.yml` workflow can successfully deploy a test service
5. Services are reachable at expected DNS names
6. Bedrock API calls work from deployed tasks
7. The scaffolder template flow completes end-to-end

---

## Functional Requirements

### 1. GitHub Organization Validation

**1.1** Verify `mvp-glaciar-org` exists and user has admin/push permissions
- List repos in the org
- Verify GitHub PAT has `repo` and `org` scopes
- Test ability to create a repo in the org

**1.2** Verify no existing test repos that will interfere
- Search for repos named `test-*`, `demo-*`, `reflection-*`
- Clean up any stale test repos from prior test runs

---

### 2. AWS Infrastructure Validation

**2.1** Verify Terraform outputs are available
- `ecs_dev_cluster_arn`, `ecs_prod_cluster_arn` exist
- `ecs_dev_alb_listener_arn`, `ecs_prod_alb_listener_arn` exist
- All security group IDs and wildcard cert ARNs are present

**2.2** Verify ECS clusters are running
- List tasks in both `backstage-apps-dev` and `backstage-apps-prod` clusters
- Both clusters should exist (may have 0 tasks if no services deployed yet)

**2.3** Verify Route53 DNS setup
- `*.dev.glaciar.org` wildcard record exists and points to dev ALB
- `*.prod.glaciar.org` wildcard record exists and points to prod ALB
- Query a test subdomain (e.g., `test-nslookup.dev.glaciar.org`) and verify it resolves to ALB IP

**2.4** Verify ALB is accepting traffic
- Check ALB security group allows inbound 443 (HTTPS)
- Check ALB listener exists on port 443 with TLS cert
- Perform health check: `curl -k https://<any-subdomain>.dev.glaciar.org` should return 404 (no service, but ALB responds)

---

### 3. Scaffolder Template Validation

**3.1** Verify AI Ops Assistant template exists
- Backstage can load the template
- Form fields render correctly (including "Deploy to ECS" option)

**3.2** Verify template parameters
- Service name field works
- Owner field works
- ECS environment dropdown (dev | prod) works
- `deploy_to_ecs` checkbox works

**3.3** Verify template actions
- `github:actions:dispatch` action to `deploy-service.yml` is correctly configured
- Template references correct GitHub repo and workflow

---

### 4. Service Deployment Workflow

**4.1** Deploy a test service end-to-end
- Service name: `test-reflection-ai` (follows naming convention)
- Deploy to dev environment
- GitHub Actions workflow runs without errors
- `terraform apply -target` completes successfully
- Docker image builds and pushes to ECR
- ECS service is created and reaches "running" state

**4.2** Verify service is reachable
- DNS resolves: `test-reflection-ai.dev.backstage.glaciar.org` → ALB IP
- HTTPS works: `curl -k https://test-reflection-ai.dev.backstage.glaciar.org` → 200 (frontend served)
- Backend API is reachable: `/api/health` returns 200
- Frontend loads in browser (React SPA)

**4.3** Verify Bedrock integration
- POST to `/api/chat` with a test message
- Bedrock receives the request (check CloudWatch logs)
- Response is valid JSON with completion
- Streaming endpoint `/api/chat/stream` works

---

### 5. Cleanup & Teardown

**5.1** After successful testing, tear down the test service
- Remove service from ECS (`backstage-apps-dev` cluster)
- Delete ALB listener rule
- Delete ECR repository
- Remove module block from `terraform/services.tf` (or mark as commented)
- Verify cleanup is idempotent (can run twice without error)

**5.2** Leave infrastructure in clean state
- No dangling resources
- No test repos in `mvp-glaciar-org` (remove `test-reflection-ai`)
- `terraform/services.tf` is clean or documented

---

## Non-Functional Requirements

**NFR-1** All tests must be **automated and reproducible** — shell scripts or Terraform validation blocks, not manual steps.

**NFR-2** Tests must be **idempotent** — running the reflection test twice should not fail (cleanup old test service if it exists).

**NFR-3** All test results must be **logged and reportable** — generate a summary report showing pass/fail for each validation.

**NFR-4** Tests must not **pollute production** — all tests run against `dev` environment only (except final verification that prod cluster exists).

**NFR-5** **Debugging support** — when a test fails, provide detailed error output and next steps for investigation.

---

## Success Criteria

- [ ] All GitHub org validations pass
- [ ] All AWS infrastructure checks pass
- [ ] All Route53 DNS checks pass
- [ ] Scaffolder template loads and renders correctly
- [ ] `test-reflection-ai` service deploys successfully to `backstage-apps-dev`
- [ ] Service is reachable at `https://test-reflection-ai.dev.backstage.glaciar.org`
- [ ] Bedrock API calls work from the deployed service
- [ ] Cleanup completes without errors
- [ ] Summary report generated (pass/fail, duration, errors)

---

## Out of Scope

- Performance testing (latency, throughput)
- Load testing
- Disaster recovery / failover testing
- Multi-region deployment
- Blue/green deployment validation
