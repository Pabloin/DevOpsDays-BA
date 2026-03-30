# Terraform Infrastructure

Deploys the Backstage portal to AWS (VPC, ECS Fargate, RDS, ALB, ECR, Secrets Manager).

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with a profile that has sufficient permissions

## First-time Setup

### 1. Bootstrap — create the S3 state bucket

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

This creates the `backstage-portal-tfstate` S3 bucket used to store remote state.
Only needs to be run once.

### 2. Configure non-secret variables

Copy the example and edit as needed:

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` is gitignored — safe to put non-secret values there.

## Handling Secrets

The following variables are sensitive and should never be committed:

- `github_oauth_client_id`
- `github_oauth_client_secret`

### Option A — inline environment variables (simplest)

```bash
TF_VAR_github_oauth_client_id="your-client-id" \
TF_VAR_github_oauth_client_secret="your-client-secret" \
terraform apply
```

### Option B — export in shell session

```bash
export TF_VAR_github_oauth_client_id="your-client-id"
export TF_VAR_github_oauth_client_secret="your-client-secret"
terraform apply
```

### Option C — local .env file (gitignored)

Create `terraform/.env`:

```bash
export TF_VAR_github_oauth_client_id="your-client-id"
export TF_VAR_github_oauth_client_secret="your-client-secret"
```

Then source it before applying:

```bash
source .env
terraform apply
```

### Option D — CI/CD (GitHub Actions)

```yaml
- name: Terraform Apply
  env:
    TF_VAR_github_oauth_client_id: ${{ secrets.GITHUB_OAUTH_CLIENT_ID }}
    TF_VAR_github_oauth_client_secret: ${{ secrets.GITHUB_OAUTH_CLIENT_SECRET }}
  run: terraform apply -auto-approve
```

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

To use a specific AWS profile:

```bash
export AWS_PROFILE=your-profile-name
```
