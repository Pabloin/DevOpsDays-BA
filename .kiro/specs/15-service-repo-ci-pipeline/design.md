# Design: Service Repo CI Pipeline (`15-service-repo-ci-pipeline`)

## Architecture

```
Push to main
  mvp-glaciar-org/<service>
    ↓
  .github/workflows/deploy.yml
    ↓ repository_dispatch (via GH_PAT)
  Pabloin/DevOpsDays-BA
    ↓
  .github/workflows/deploy-service.yml
    (on: repository_dispatch, event-type: deploy-service)
    ↓
  AWS (OIDC) → ECR → ECS force-new-deployment
```

---

## Files to Create/Modify

### 1. Template content — new file
```
backstage-portal/examples/template/ai-ops-assistant/content/
  └── .github/workflows/deploy.yml
```

Triggers on push to `main`, dispatches to parent repo:
```yaml
on:
  push:
    branches: [main]

jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.GH_PAT }}
          repository: Pabloin/DevOpsDays-BA
          event-type: deploy-service
          client-payload: |
            {
              "service_name": "${{ values.service_name }}",
              "environment": "${{ values.ecs_environment }}",
              "bedrock_model_id": "${{ values.bedrock_model_id }}"
            }
```

### 2. Parent repo workflow — add trigger
```
.github/workflows/deploy-service.yml
```

Add `repository_dispatch` trigger alongside existing `workflow_dispatch`:
```yaml
on:
  workflow_dispatch:
    inputs: ...
  repository_dispatch:
    types: [deploy-service]
```

Inputs sourced from either `github.event.inputs` or `github.event.client_payload`.

### 3. Org secret
`GH_PAT` set at `mvp-glaciar-org` org level — inherited by all repos.

---

## Input Resolution in deploy-service.yml

Since inputs come from two sources (`workflow_dispatch` vs `repository_dispatch`), use this pattern:

```yaml
env:
  SERVICE_NAME: ${{ github.event.inputs.service_name || github.event.client_payload.service_name }}
  ENVIRONMENT:  ${{ github.event.inputs.environment  || github.event.client_payload.environment }}
  MODEL_ID:     ${{ github.event.inputs.bedrock_model_id || github.event.client_payload.bedrock_model_id }}
```
