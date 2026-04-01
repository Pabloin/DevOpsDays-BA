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

```bash
# Build
cd backstage-portal
yarn build:backend
docker build -f packages/backend/Dockerfile -t backstage .

# Push to ECR
aws ecr get-login-password --region us-east-1 --profile chile | \
  docker login --username AWS --password-stdin \
  703671890483.dkr.ecr.us-east-1.amazonaws.com
docker tag backstage 703671890483.dkr.ecr.us-east-1.amazonaws.com/backstage-mvp:amd64
docker push 703671890483.dkr.ecr.us-east-1.amazonaws.com/backstage-mvp:amd64

# Deploy
aws ecs update-service --cluster backstage-mvp-cluster \
  --service backstage-mvp-service --force-new-deployment \
  --region us-east-1 --profile chile
```

## Infrastructure changes

```bash
cd terraform
source .env.prod
terraform plan
terraform apply
```
