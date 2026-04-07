# Tasks: Environment Reflection & Testing (`14-environment-reflection`)

## Phase 1: GitHub Organization Validation
- [ ] 1.1 Create helper function `gh_verify_org()` in reflection-test.sh
- [ ] 1.2 List repos in `mvp-glaciar-org` and verify non-empty
- [ ] 1.3 Check GitHub PAT scopes (`gh auth status`)
- [ ] 1.4 Clean up any stale test repos from prior runs
- [ ] 1.5 Log results and detect failures

## Phase 2: AWS Infrastructure Validation
- [ ] 2.1 Create helper function `tf_verify_outputs()` in reflection-test.sh
- [ ] 2.2 Query Terraform outputs for all ECS/ALB/cert ARNs
- [ ] 2.3 Verify both ECS clusters exist (`backstage-apps-dev`, `backstage-apps-prod`)
- [ ] 2.4 List ALBs and verify one exists per environment
- [ ] 2.5 Verify ALB listeners on port 443 with TLS cert
- [ ] 2.6 Log results and detect failures

## Phase 3: Route53 DNS Validation
- [ ] 3.1 Create helper function `dns_verify_wildcards()` in reflection-test.sh
- [ ] 3.2 Query Route53 for `*.dev.glaciar.org` wildcard record
- [ ] 3.3 Query Route53 for `*.prod.glaciar.org` wildcard record
- [ ] 3.4 Test DNS resolution with `nslookup` on test subdomain
- [ ] 3.5 Verify resolved IP matches ALB IP
- [ ] 3.6 Log results and detect failures

## Phase 4: Scaffolder Template Validation
- [ ] 4.1 Create helper function `template_verify()` in reflection-test.sh
- [ ] 4.2 Check template file exists: `backstage-portal/examples/template/ai-ops-assistant/template.yaml`
- [ ] 4.3 Validate template YAML syntax with `yq`
- [ ] 4.4 Extract and verify form fields exist (service_name, owner, deploy_to_ecs, ecs_environment)
- [ ] 4.5 Verify `github:actions:dispatch` step references `deploy-service.yml`
- [ ] 4.6 Log results and detect failures

## Phase 5: Service Deployment Test
- [ ] 5.1 Create helper function `service_deploy_test()` in reflection-test.sh
- [ ] 5.2 Create test repo: `gh repo create mvp-glaciar-org/test-reflection-ai --public`
- [ ] 5.3 Clone test repo and commit initial code (from ai-ops-assistant template)
- [ ] 5.4 Push initial code to test repo
- [ ] 5.5 Trigger `deploy-service.yml` workflow via `gh workflow run` with test service name
- [ ] 5.6 Wait for workflow to complete (poll with timeout 10m)
- [ ] 5.7 Check workflow exit status (success vs failure)
- [ ] 5.8 Query ECS service status: `backstage-apps-dev` cluster, `test-reflection-ai-dev` service
- [ ] 5.9 Wait for service to reach running state (poll with timeout 5m)
- [ ] 5.10 Test DNS resolution: `nslookup test-reflection-ai.dev.backstage.glaciar.org`
- [ ] 5.11 Test HTTPS endpoint: `curl -k -I https://test-reflection-ai.dev.backstage.glaciar.org`
- [ ] 5.12 Test API health check: `curl -k https://test-reflection-ai.dev.backstage.glaciar.org/api/health`
- [ ] 5.13 Test Bedrock chat endpoint: POST to `/api/chat` with test message
- [ ] 5.14 Verify Bedrock response is valid JSON with content
- [ ] 5.15 Log all results and detect failures

## Phase 6: Cleanup & Report
- [ ] 6.1 Create helper function `cleanup_test_service()` in reflection-test.sh
- [ ] 6.2 Scale down ECS service to desired_count=0
- [ ] 6.3 Wait for service to stabilize
- [ ] 6.4 Delete test repo: `gh repo delete mvp-glaciar-org/test-reflection-ai`
- [ ] 6.5 Verify no test resources remain (query ECS, ECR, Route53)
- [ ] 6.6 Create helper function `generate_report()` for summary output
- [ ] 6.7 Write report to `REFLECTION_TEST_REPORT.md` with pass/fail for each check
- [ ] 6.8 Display final summary to user (pass/fail, timing, errors)

## Integration & Documentation
- [ ] 7.1 Create `.kiro/specs/14-environment-reflection/.config.kiro` with spec metadata
- [ ] 7.2 Add spec 14 to main README or spec index
- [ ] 7.3 Create `scripts/reflection-test.sh` executable with all helper functions
- [ ] 7.4 Create `REFLECTION_TEST_GUIDE.md` with instructions for running the test
- [ ] 7.5 Test the full script locally: `./scripts/reflection-test.sh`
- [ ] 7.6 Document any manual setup steps needed before running test

## Delivery
- [ ] 8.1 Commit all changes to feature branch: `feature/14-environment-reflection`
- [ ] 8.2 Create PR via `gh pr create`
- [ ] 8.3 Share PR URL with user for review
