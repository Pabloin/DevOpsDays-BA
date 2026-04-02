# Implementation Plan: Scaffolder DNS Records (`09-scaffolder-dns-records`)

## Overview

Enhance the AI Ops Assistant template to automatically create Route53 DNS records when users scaffold a new app. When scaffolding "demo3", the template creates `demo3.backstage.glaciar.org` pointing to the main ALB.

## Tasks

- [ ] 1. Update template form to capture custom domain
  - [ ] 1.1 Add "Domain configuration" section to template.yaml
    - Optional parameter: `custom_domain` (pattern: `*.backstage.glaciar.org` or empty)
    - Default: empty (DNS setup is optional)
    - _Requirements: 2.1_
  - [ ] 1.2 Add conditional scaffolder step: `create-dns-record` (only if custom_domain provided)
    - _Requirements: 1.1_

- [ ] 2. Create custom scaffolder action (or Lambda webhook)
  - [ ] 2.1 Design custom action handler or AWS Lambda
    - Receives: domain name, service name, repository URL
    - Creates Route53 A alias record → ALB
    - Updates ACM certificate with new SAN
    - _Requirements: 1.2, 1.3, 1.4_
  - [ ] 2.2 Integrate with Backstage (plugin or custom action)
    - OR set up Lambda + API Gateway webhook for GitHub Actions to call
    - _Requirements: 1.1_

- [ ] 3. Update root Terraform to accept dynamic SANs
  - [ ] 3.1 Modify `terraform/modules/dns/variables.tf`
    - Add variable: `additional_domains = []` (list of strings)
    - _Requirements: 1.4_
  - [ ] 3.2 Modify `aws_acm_certificate.main`
    - Set `subject_alternative_names = var.additional_domains`
    - _Requirements: 1.4, 1.5_
  - [ ] 3.3 Wire variable through root module
    - Update `terraform/main.tf` to pass SANs from tfvars or API
    - _Requirements: 1.4_

- [ ] 4. Test end-to-end
  - [ ] 4.1 Scaffold a test app with custom_domain = "demo3.backstage.glaciar.org"
    - Scaffolder creates DNS record
    - Certificate updated with new SAN
    - _Requirements: 1.2, 1.4, 1.5_
  - [ ] 4.2 Verify DNS resolution: `dig demo3.backstage.glaciar.org`
    - Should resolve to ALB IP
    - _Requirements: 1.3_
  - [ ] 4.3 Verify HTTPS: `curl -I https://demo3.backstage.glaciar.org`
    - 200/302, valid certificate for demo3 domain
    - _Requirements: 1.3_

- [ ] 5. Update template documentation
  - [ ] 5.1 Add section to template README: "Custom domains"
    - Explain the optional domain parameter
    - Note DNS propagation delay (5-10 min)
    - _Requirements: 2.3, 1.5_

- [ ] 6. Commit and merge
  - [ ] 6.1 Commit all changes to feature/09-scaffolder-dns-records
  - [ ] 6.2 Create PR to main
  - [ ] 6.3 Merge and verify template works end-to-end
