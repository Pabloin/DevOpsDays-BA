# Implementation Plan: NAT Gateway to VPC Interface Endpoints

## Overview

Replace `aws_nat_gateway` and `aws_eip` with VPC Interface Endpoints (ECR, Secrets Manager, CloudWatch Logs) and an S3 Gateway Endpoint, saving ~$28/month with no application code changes.

## Tasks

- [x] 1. Remove NAT Gateway resources from VPC module
  - Delete `aws_eip.nat` and `aws_nat_gateway.main` resources from `terraform/modules/vpc/main.tf`
  - Remove the `0.0.0.0/0` default route from the private route table
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Add `aws_region` variable to VPC module
  - Declare `aws_region` input variable of type `string` in `terraform/modules/vpc/variables.tf`
  - _Requirements: 5.1_

- [x] 3. Provision endpoint security group and VPC endpoints
  - [x] 3.1 Add `aws_security_group.vpc_endpoints` to `terraform/modules/vpc/main.tf`
    - Allow inbound TCP 443 from `var.private_subnet_cidrs`
    - _Requirements: 4.1, 4.2_
  - [x] 3.2 Add S3 Gateway Endpoint (`aws_vpc_endpoint.s3`)
    - Associate with the private route table
    - _Requirements: 3.1, 3.2_
  - [x] 3.3 Add Interface Endpoints for `ecr.api`, `ecr.dkr`, `secretsmanager`, `logs`
    - Attach to all private subnets, attach endpoint security group, enable private DNS
    - Use `var.aws_region` for service name construction
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 4.3, 5.2_

- [x] 4. Wire `aws_region` through root module
  - Pass `aws_region = var.aws_region` to `module "vpc"` in `terraform/main.tf`
  - _Requirements: 5.3_

- [x] 5. Add cost documentation
  - Create `terraform/README_COSTS.md` with before/after monthly cost breakdown
  - List all five endpoints with types and cost contributions
  - Update `terraform/README.md` with cost note and deployment steps
  - _Requirements: 7.1, 7.2, 7.3_

- [x] 6. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

---

## Claude Update (2026-04-01)

**Known limitation discovered**: Removing the NAT Gateway breaks GitHub OAuth authentication.
The Backstage backend needs outbound internet access to call `https://github.com/login/oauth/access_token`
during the OAuth token exchange. VPC endpoints only cover AWS services — they cannot route traffic
to external APIs like GitHub.

**Impact**: The `/api/auth/github/start` endpoint returns a 302 redirect (works — browser-side),
but when GitHub redirects back with the authorization code, the backend cannot exchange it for a
token because it has no route to `github.com`. The auth flow fails silently with a 401.

**Resolution**: See spec `07-single-az-nat` — adds a single-AZ NAT Gateway to restore outbound
internet access for ECS tasks at ~$16/month (half the cost of the original dual-AZ setup).
