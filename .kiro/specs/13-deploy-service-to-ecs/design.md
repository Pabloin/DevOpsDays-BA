# Design: Deploy Scaffolded Service to ECS (`13-deploy-service-to-ecs`)

## Architecture Overview

```
User scaffolds AI assistant via Backstage
  └── Checks "Deploy to ECS" + picks "dev"
        ↓
  Backstage triggers deploy-service.yml (workflow_dispatch)
        ↓
  GitHub Actions:
    1. Checkout service repo (mvp-glaciar-org/<service_name>)
    2. Checkout DevOpsDays-BA (infra repo)
    3. Append module block to terraform/services.tf
    4. terraform apply -target=module.svc_<name>_dev
       → ECR repo created
       → ECS task definition registered
       → ECS service created in backstage-apps-dev cluster
       → ALB listener rule: my-app.dev.backstage.glaciar.org → target group
    5. docker build + push to ECR
    6. Force new ECS deployment
        ↓
  Service live at https://my-app.dev.backstage.glaciar.org
```

---

## Container Architecture: Single-Container App

The AI Ops Assistant runs as **one container** in production:

```
Node.js backend (port 3001)
  ├── /api/chat          → Bedrock API call
  ├── /api/chat/stream   → Bedrock streaming
  └── /*                 → serve static files from public/ (built React app)
```

### Dockerfile (multi-stage)

```dockerfile
# Stage 1: build React frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/yarn.lock ./
RUN yarn install --frozen-lockfile
COPY frontend/ ./
RUN yarn build
# Output: /app/frontend/dist/

# Stage 2: production Node.js server
FROM node:22-alpine
WORKDIR /app
COPY backend/package.json backend/yarn.lock ./
RUN yarn install --frozen-lockfile --production
COPY backend/ ./
COPY prompt.md ../prompt.md
COPY --from=frontend-builder /app/frontend/dist ./public
EXPOSE 3001
CMD ["node", "index.js"]
```

### Backend change: serve static files

Add to `backend/index.js` template (after CORS middleware):
```js
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.use(express.static(path.join(__dirname, 'public')));
```

---

## Terraform Module: `deploy-service`

**File**: `terraform/modules/deploy-service/`

```
modules/deploy-service/
  main.tf       — ECR, ECS task def, ECS service, target group, listener rule, SGs, IAM
  variables.tf  — service_name, environment, cluster_arn, alb_listener_arn, etc.
  outputs.tf    — ecr_repository_url, service_url, ecs_service_name
```

### Key resources

| Resource | Name pattern |
|----------|-------------|
| ECR repo | `<service_name>-<env>` |
| ECS task def | `<service_name>-<env>` |
| ECS service | `<service_name>-<env>` |
| ALB target group | `<service_name>-<env>-tg` (max 32 chars) |
| ALB listener rule | priority = `abs(hash(service+env)) % 49000 + 1000` |
| Task SG | `<service_name>-<env>-task-sg` |
| Task execution role | `<service_name>-<env>-exec-role` |
| Task role | `<service_name>-<env>-task-role` |

### IAM Task Role (Bedrock permissions)

```hcl
statement {
  actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
  resources = ["arn:aws:bedrock:${var.aws_region}::foundation-model/*"]
}
```

### ALB Listener Rule

```hcl
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.alb_listener_arn
  priority     = local.rule_priority

  condition {
    host_header {
      values = ["${var.service_name}.${var.environment}.${var.base_domain}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}
```

---

## `terraform/services.tf`

This file accumulates service deployments. Starts as:

```hcl
# Scaffolded service deployments
# This file is managed by the deploy-service.yml GitHub Actions workflow.
# Each module block below represents one service deployed to one environment.
```

The workflow appends blocks like:

```hcl
module "svc_my_ai_assistant_dev" {
  source = "./modules/deploy-service"

  service_name          = "my-ai-assistant"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_arn           = module.ecs_env_dev.cluster_arn
  alb_listener_arn      = module.ecs_env_dev.alb_listener_arn_https
  alb_security_group_id = module.ecs_env_dev.alb_security_group_id
  bedrock_model_id      = "anthropic.claude-3-haiku-20240307-v1:0"
  project               = "backstage"
}
```

Module name format: `svc_<service_name_underscored>_<env>` (hyphens → underscores for valid HCL identifiers).

---

## GitHub Actions Workflow: `deploy-service.yml`

```yaml
on:
  workflow_dispatch:
    inputs:
      service_name: { required: true }
      environment:  { required: true, type: choice, options: [dev, prod] }
      bedrock_model_id: { required: true }
      image_tag: { default: latest }

jobs:
  deploy:
    steps:
      # 1. Checkout infra repo (this repo)
      - uses: actions/checkout@v4
        with: { path: infra }

      # 2. Checkout service repo
      - uses: actions/checkout@v4
        with:
          repository: mvp-glaciar-org/${{ inputs.service_name }}
          token: ${{ secrets.GH_PAT }}
          path: service

      # 3. AWS credentials
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}

      # 4. ECR login
      - uses: aws-actions/amazon-ecr-login@v2

      # 5. Append module to services.tf (idempotent — skip if already present)
      - name: Register service in Terraform
        run: |
          cd infra
          MODULE_NAME="svc_$(echo ${{ inputs.service_name }} | tr '-' '_')_${{ inputs.environment }}"
          if ! grep -q "module \"${MODULE_NAME}\"" terraform/services.tf; then
            cat >> terraform/services.tf << EOF
          module "${MODULE_NAME}" {
            source                = "./modules/deploy-service"
            service_name          = "${{ inputs.service_name }}"
            environment           = "${{ inputs.environment }}"
            vpc_id                = module.vpc.vpc_id
            private_subnet_ids    = module.vpc.private_subnet_ids
            cluster_arn           = module.ecs_env_${{ inputs.environment }}.cluster_arn
            alb_listener_arn      = module.ecs_env_${{ inputs.environment }}.alb_listener_arn_https
            alb_security_group_id = module.ecs_env_${{ inputs.environment }}.alb_security_group_id
            bedrock_model_id      = "${{ inputs.bedrock_model_id }}"
            project               = "backstage"
          }
          EOF
            git config user.email "backstage-bot@glaciar.org"
            git config user.name "backstage-bot"
            git add terraform/services.tf
            git commit -m "feat: register ${{ inputs.service_name }} in ${{ inputs.environment }}"
            git push
          fi

      # 6. Terraform apply (only this service)
      - name: Terraform apply
        run: |
          cd infra/terraform
          terraform init
          MODULE_NAME="svc_$(echo ${{ inputs.service_name }} | tr '-' '_')_${{ inputs.environment }}"
          terraform apply -auto-approve -target=module.${MODULE_NAME}

      # 7. Get ECR URL
      - name: Get ECR URL
        id: ecr
        run: |
          cd infra/terraform
          MODULE_NAME="svc_$(echo ${{ inputs.service_name }} | tr '-' '_')_${{ inputs.environment }}"
          ECR_URL=$(terraform output -raw ${MODULE_NAME}_ecr_url 2>/dev/null || \
            terraform output -json | jq -r ".${MODULE_NAME}_ecr_url.value")
          echo "url=${ECR_URL}" >> $GITHUB_OUTPUT

      # 8. Build and push image
      - name: Build and push
        run: |
          cd service
          docker build -t ${{ steps.ecr.outputs.url }}:${{ inputs.image_tag }} .
          docker push ${{ steps.ecr.outputs.url }}:${{ inputs.image_tag }}

      # 9. Force new ECS deployment
      - name: Deploy to ECS
        run: |
          CLUSTER="backstage-apps-${{ inputs.environment }}"
          SERVICE="${{ inputs.service_name }}-${{ inputs.environment }}"
          aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
          aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
```

---

## AI Ops Assistant Template Changes

### New form step

```yaml
- title: Deploy to ECS (optional)
  properties:
    deploy_to_ecs:
      title: Deploy to shared ECS environment
      type: boolean
      default: false
    ecs_environment:
      title: Target environment
      type: string
      enum: [dev, prod]
      default: dev
      ui:widget: select
```

### New conditional step

```yaml
- id: deploy-ecs
  name: Deploy to ECS
  if: ${{ parameters.deploy_to_ecs }}
  action: github:actions:dispatch
  input:
    repoUrl: github.com?owner=Pabloin&repo=DevOpsDays-BA
    workflowId: deploy-service.yml
    branchOrTagName: main
    workflowInputs:
      service_name: ${{ parameters.service_name }}
      environment: ${{ parameters.ecs_environment }}
      bedrock_model_id: ${{ parameters.bedrock_model }}
```

---

## What Is NOT in This Spec

- Blue/green deployments or rolling updates (ECS handles this natively)
- Custom environment variables per service beyond what's in the template
- Removal/teardown of a deployed service (future spec)
- Other template types (e.g. React app, API) — those will reuse the same `deploy-service` module
