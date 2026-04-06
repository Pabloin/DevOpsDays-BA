# Implementation Plan: Scaffolder DNS Records (`09-scaffolder-dns-records`)

## Overview

Enhance the AI Ops Assistant template to automatically create Route53 DNS records when users scaffold a new app. When scaffolding "demo3", the template creates `demo3.backstage.glaciar.org` pointing to the main ALB.

## Tasks

- [x] 1. Update template form to capture DNS option
  - [x] 1.1 Add `create_dns` boolean parameter (default: true) to template.yaml
  - [x] 1.2 Add conditional `aws:route53:create-dns-record` step after catalog registration

- [x] 2. Create custom scaffolder action
  - [x] 2.1 Create `@internal/plugin-scaffolder-backend-module-route53` plugin
    - Action ID: `aws:route53:create-dns-record`
    - Reads Route53 config from env vars (ROUTE53_HOSTED_ZONE_ID, ALB_DNS_NAME, etc.)
    - Uses AWS SDK Route53Client to UPSERT A alias record → ALB
  - [x] 2.2 Register plugin in backend (`packages/backend/src/index.ts`)

- [x] 3. Update Terraform infrastructure
  - [x] 3.1 Add wildcard SAN to ACM certificate (`*.backstage.glaciar.org`)
  - [x] 3.2 Add Route53 IAM permissions to ECS task role
  - [x] 3.3 Pass Route53/ALB env vars to ECS task definition
  - [x] 3.4 Wire new variables through root module (main.tf → ecs module)
  - [x] 3.5 Add DNS module outputs (hosted_zone_arn, alb_dns_name, alb_zone_id)

- [ ] 4. Test end-to-end
  - [ ] 4.1 Run `terraform plan` to verify infrastructure changes
  - [ ] 4.2 Apply Terraform (wildcard cert + IAM permissions)
  - [ ] 4.3 Deploy Backstage with new plugin
  - [ ] 4.4 Scaffold a test app with DNS enabled
  - [ ] 4.5 Verify: `dig {service_name}.backstage.glaciar.org` resolves to ALB
  - [ ] 4.6 Verify: `curl -I https://{service_name}.backstage.glaciar.org` returns valid response

- [ ] 5. Commit and merge
  - [ ] 5.1 Commit all changes to feature/09-scaffolder-dns-records
  - [ ] 5.2 Create PR to main
  - [ ] 5.3 Merge and verify template works end-to-end
