# Requirements: Service Repo CI Pipeline (`15-service-repo-ci-pipeline`)

## Goal

Every scaffolded service repo (`mvp-glaciar-org/<service-name>`) should automatically redeploy to ECS when code is pushed to `main` — without requiring a manual workflow dispatch from the infra repo.

---

## Problem

Currently:
1. Scaffolder creates `mvp-glaciar-org/<service>` repo with frontend + backend code
2. To redeploy after a code change, someone must manually trigger `deploy-service.yml` in `Pabloin/DevOpsDays-BA`
3. AWS OIDC trust is scoped to `Pabloin/DevOpsDays-BA` only — service repos cannot assume the AWS role directly

## Solution

Use **repository dispatch** (Option A):
- Service repo push → triggers `repository_dispatch` event on `Pabloin/DevOpsDays-BA` via `GH_PAT`
- Parent repo handles deployment using its OIDC + AWS credentials

No Terraform changes required. Works with existing OIDC setup.

---

## Functional Requirements

**1. Auto-deploy on push**
- Every push to `main` in a service repo must trigger a redeploy to ECS
- No manual steps required

**2. Template includes deploy workflow**
- The scaffolder template must include `.github/workflows/deploy.yml` in the service repo content
- Workflow uses `repository_dispatch` to trigger `Pabloin/DevOpsDays-BA`
- Payload includes: `service_name`, `environment`, `bedrock_model_id`

**3. Parent repo handles dispatch event**
- `deploy-service.yml` in `Pabloin/DevOpsDays-BA` must listen for `repository_dispatch` with `event-type: deploy-service`
- Extracts `service_name`, `environment`, `bedrock_model_id` from payload

**4. GH_PAT available in service repos**
- `GH_PAT` must be available as an org-level secret in `mvp-glaciar-org`
- All current and future service repos inherit it automatically

**5. Existing service repos updated**
- `test-reflection-ai-02` must get the `deploy.yml` workflow added manually

---

## Non-Functional Requirements

- No new AWS infrastructure required
- Works with existing OIDC trust policy
- Idempotent — pushing twice should not cause issues
- Org secret set once, applies to all future scaffolded repos

---

## Out of Scope

- Per-environment branch strategy (e.g. `prod` branch → prod deploy)
- PR preview environments
- Expanding OIDC trust to `mvp-glaciar-org/*` (Option B — future)
