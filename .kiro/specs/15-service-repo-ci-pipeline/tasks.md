# Tasks: Service Repo CI Pipeline (`15-service-repo-ci-pipeline`)

## Implementation

- [ ] 1.1 Add `.github/workflows/deploy.yml` to scaffolder template content
- [ ] 1.2 Add `repository_dispatch` trigger to `deploy-service.yml` in parent repo
- [ ] 1.3 Update `deploy-service.yml` steps to resolve inputs from both `workflow_dispatch` and `repository_dispatch` payloads
- [ ] 1.4 Set `GH_PAT` as org-level secret in `mvp-glaciar-org`
- [ ] 1.5 Add `deploy.yml` workflow to existing `test-reflection-ai-02` repo manually

## Validation

- [ ] 2.1 Push a change to `test-reflection-ai-02/main` and verify workflow triggers automatically
- [ ] 2.2 Verify `deploy-service.yml` completes successfully from dispatch event
- [ ] 2.3 Verify ECS service redeployed with new image

## Delivery

- [ ] 3.1 Commit all changes to feature branch `feature/15-service-repo-ci-pipeline`
- [ ] 3.2 Create PR and merge to main
