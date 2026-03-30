# Terraform Infrastructure

Deploys the Backstage portal to AWS: VPC, ECS Fargate, RDS, ALB, ECR, Secrets Manager.

Networking uses VPC endpoints instead of a NAT Gateway to reduce cost (~$60/month vs ~$88/month).
See [README_COSTS.md](./README_COSTS.md) for the full breakdown.

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with a profile that has sufficient permissions

## First-time Setup

### 1. Set your AWS profile

```bash
export AWS_PROFILE=chile
aws sts get-caller-identity  # verify you're on the right account
```

### 2. Bootstrap — create the S3 state bucket

Run once to create the `backstage-portal-tfstate` S3 bucket used for remote state:

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

### 3. Configure non-secret variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` is gitignored — safe to put non-secret values there.

## Handling Secrets

The following variables are sensitive and should never be committed:

- `github_oauth_client_id`
- `github_oauth_client_secret`

### Option A — inline (simplest)

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
terraform plan -out=tfplan
terraform apply tfplan
```

## Notes

- The ALB HTTP listener redirects to HTTPS. Set `acm_certificate_arn` in `terraform.tfvars` to enable HTTPS, or leave empty for HTTP only.
- ECS tasks will fail to start until a Docker image is pushed to ECR (handled by the CI/CD pipeline in `03-ci-cd-pipeline`).
- RDS runs in private subnets — only accessible from ECS tasks via the security group.
