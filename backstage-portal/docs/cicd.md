# CI/CD Pipeline

Every push to `main` triggers the GitHub Actions pipeline at
`.github/workflows/deploy.yml`.

## Pipeline steps

```
git push origin main
    │
    ▼
┌─────────────────────────────────┐
│ 1. Checkout code                │
│ 2. Assume AWS role (OIDC)       │
│ 3. Login to ECR                 │
│ 4. yarn install --immutable     │
│ 5. yarn tsc                     │
│ 6. yarn build:backend           │
│ 7. docker build + push to ECR   │
│    tags: :<git-sha> + :latest   │
│ 8. ECS rolling deploy           │
│    - describe current task def  │
│    - register new revision      │
│    - update service             │
│    - wait until stable          │
└─────────────────────────────────┘
```

## Required GitHub secret

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::703671890483:role/backstage-mvp-github-actions-role` |

No AWS access keys stored — authentication uses OIDC.

## Hardcoded values (non-secret)

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `backstage-mvp` |
| `ECS_CLUSTER` | `backstage-mvp-cluster` |
| `ECS_SERVICE` | `backstage-mvp-service` |
| `TASK_DEFINITION_FAMILY` | `backstage-mvp-backstage` |

## IAM permissions (least-privilege)

The GitHub Actions role has only what the pipeline needs:

| Permission | Scope |
|---|---|
| `ecr:GetAuthorizationToken` | `*` |
| `ecr:Push*` | ECR repository ARN |
| `ecs:RegisterTaskDefinition`, `ecs:DescribeTaskDefinition` | `*` |
| `ecs:DescribeServices`, `ecs:UpdateService` | cluster + service ARNs |
| `iam:PassRole` | ECS execution role ARN |
