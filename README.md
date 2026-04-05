# Backstage Developer Portal

A production-ready Backstage developer portal deployed on AWS with GitHub OAuth authentication, software templates, and TechDocs.

## Quick Start

### Prerequisites

- Node.js 22+
- Yarn 4.4.1 (included via Yarn Berry)
- Docker (for local development with PostgreSQL)
- AWS CLI (for infrastructure management)
- Terraform >= 1.10 (for infrastructure deployment)

### Local Development

1. **Clone and install dependencies:**

```bash
git clone <repository-url>
cd backstage-portal
yarn install
```

2. **Start the portal:**

```bash
yarn start
```

This starts both the frontend (http://localhost:3000) and backend (http://localhost:7007).

The local setup uses:
- In-memory SQLite database
- Guest authentication (no GitHub OAuth required)
- Local TechDocs builder

### Available Commands

From the `backstage-portal/` directory:

```bash
yarn start              # Start frontend and backend
yarn build:backend      # Build backend for production
yarn tsc                # Type check all packages
yarn lint:all           # Lint all packages
yarn test               # Run tests
```

## Project Structure

```
.
├── backstage-portal/           # Backstage monorepo
│   ├── packages/
│   │   ├── app/               # Frontend (React, new frontend system)
│   │   └── backend/           # Backend (Node.js)
│   ├── plugins/               # Custom plugins (empty)
│   ├── examples/              # Sample catalog entities and templates
│   └── docs/                  # Project documentation
├── terraform/                 # AWS infrastructure as code
│   ├── modules/              # Terraform modules
│   └── bootstrap/            # S3 backend setup
├── .github/workflows/        # CI/CD pipelines
└── .kiro/                    # Kiro specs and configuration
```

## Features

- **GitHub OAuth Authentication** — Sign in with GitHub
- **Software Templates** — Scaffold new projects with the Backstage scaffolder
- **TechDocs** — Documentation as code with MkDocs
- **Software Catalog** — Centralized service catalog
- **Search** — Full-text search across catalog and docs
- **Kubernetes Integration** — View cluster resources
- **Notifications** — In-app notifications system

## Infrastructure

The portal is deployed on AWS using Terraform:

- **Compute**: ECS Fargate
- **Database**: RDS PostgreSQL
- **Load Balancer**: Application Load Balancer with HTTPS
- **Container Registry**: Amazon ECR
- **DNS**: Route53 (`backstage.glaciar.org`)
- **Networking**: VPC with VPC endpoints (no NAT Gateway)
- **CI/CD**: GitHub Actions with OIDC

See [terraform/README.md](terraform/README.md) for infrastructure details.

## Deployment

### Automatic Deployment

Pushing to `main` triggers the GitHub Actions workflow:

1. Builds the backend
2. Creates Docker image
3. Pushes to ECR
4. Deploys to ECS Fargate

### Manual Infrastructure Updates

```bash
cd terraform
source .env.prod
export AWS_PROFILE=chile

terraform plan -out=tfplan
terraform apply tfplan
```

## Configuration

### Local Configuration

- `backstage-portal/app-config.yaml` — Base configuration
- `backstage-portal/app-config.local.yaml` — Local overrides (gitignored)

### Production Configuration

- `backstage-portal/app-config.production.yaml` — Production settings
- Environment variables injected by ECS task definition
- Secrets managed via AWS Secrets Manager

## Development Workflow

This project follows a spec-driven development approach:

1. Create a spec in `.kiro/specs/<number>-<name>/`
   - `requirements.md` — What needs to be built
   - `design.md` — How it will be built
   - `tasks.md` — Implementation checklist

2. Create a feature branch: `feature/<number>-<name>`

3. Implement the feature

4. Create a PR to merge to `main`

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Documentation

- [Architecture](backstage-portal/docs/architecture.md)
- [Authentication](backstage-portal/docs/authentication.md)
- [CI/CD](backstage-portal/docs/cicd.md)
- [Local Development](backstage-portal/docs/local-dev.md)
- [Infrastructure Costs](terraform/README_COSTS.md)

## Tech Stack

- **Frontend**: React, TypeScript, Backstage new frontend system
- **Backend**: Node.js, Express, TypeScript
- **Database**: PostgreSQL (RDS in production, SQLite in dev)
- **Infrastructure**: AWS (ECS, RDS, ALB, Route53, ECR)
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Package Manager**: Yarn 4 (Berry with PnP)

## Environment Variables

### Local Development

No environment variables required — uses in-memory SQLite and guest auth.

### Production (ECS)

Managed by Terraform and stored in AWS Secrets Manager:

- `APP_BASE_URL` — Portal URL (https://backstage.glaciar.org)
- `POSTGRES_HOST` — RDS endpoint
- `POSTGRES_PORT` — Database port (5432)
- `POSTGRES_USER` — Database user
- `POSTGRES_PASSWORD` — Database password
- `AUTH_GITHUB_CLIENT_ID` — GitHub OAuth client ID
- `AUTH_GITHUB_CLIENT_SECRET` — GitHub OAuth client secret
- `GITHUB_TOKEN` — GitHub PAT for scaffolder

## Troubleshooting

### Local Development

**Port already in use:**
```bash
# Kill processes on ports 3000 and 7007
lsof -ti:3000 | xargs kill -9
lsof -ti:7007 | xargs kill -9
```

**Dependencies not installing:**
```bash
# Clear Yarn cache and reinstall
yarn cache clean
rm -rf node_modules .yarn/cache
yarn install
```

### Production

**ECS tasks failing:**
- Check CloudWatch logs: `/ecs/backstage-mvp-backstage`
- Verify secrets in AWS Secrets Manager
- Ensure ECR image exists

**Database connection issues:**
- Verify security groups allow ECS → RDS traffic
- Check VPC endpoints are healthy
- Validate connection string

**GitHub OAuth not working:**
- Verify callback URL: `https://backstage.glaciar.org/api/auth/github/handler/frame`
- Check secrets match GitHub OAuth app settings

## Contributing

1. Create a spec in `.kiro/specs/`
2. Create a feature branch
3. Implement changes
4. Create a PR
5. Merge to `main` after review

## License

[Add your license here]

## Support

For issues or questions, please open a GitHub issue.
