# Local Development

## Prerequisites

- Node.js 22
- Yarn
- Docker (for building images)
- AWS CLI with `chile` profile (for infrastructure changes)

## Run locally

```bash
cd backstage-portal
yarn install
yarn start
```

The app runs on `http://localhost:3000`, backend on `http://localhost:7007`.

## Local config

Create `backstage-portal/app-config.local.yaml` (gitignored):

```yaml
auth:
  providers:
    github:
      development:
        clientId: YOUR_LOCAL_GITHUB_CLIENT_ID
        clientSecret: YOUR_LOCAL_GITHUB_CLIENT_SECRET

integrations:
  github:
    - host: github.com
      token: YOUR_GITHUB_PAT
```

The local GitHub OAuth app callback URL should be: `http://localhost:7007/api/auth/github/handler/frame`

## Build and deploy manually (without CI/CD)

**Note:** If building on Mac (Apple Silicon), you MUST use `--platform linux/amd64` because ECS Fargate runs on x86_64 architecture.

```bash
# Build (use --platform linux/amd64 on Mac)
cd backstage-portal
yarn build:backend
docker build --platform linux/amd64 -f packages/backend/Dockerfile -t backstage .

# Push to ECR
aws ecr get-login-password --region us-east-1 --profile chile | \
  docker login --username AWS --password-stdin \
  703671890483.dkr.ecr.us-east-1.amazonaws.com
docker tag backstage 703671890483.dkr.ecr.us-east-1.amazonaws.com/backstage-mvp:latest
docker push 703671890483.dkr.ecr.us-east-1.amazonaws.com/backstage-mvp:latest

# Deploy
aws ecs update-service --cluster backstage-mvp-cluster \
  --service backstage-mvp-service --force-new-deployment \
  --region us-east-1 --profile chile
```

**Important:** Always use the `:latest` tag for manual deployments. The CI/CD pipeline uses commit SHAs.

## Infrastructure changes

```bash
cd terraform
source .env.glaciar.org
terraform plan
terraform apply
```
