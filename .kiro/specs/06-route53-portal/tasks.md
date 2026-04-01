# Implementation Plan: Route 53 Portal Domain

## Overview

Create a `dns` Terraform module that provisions a Route 53 hosted zone, ACM certificate with DNS validation, and an alias record pointing to the ALB. Wire it into the root module, replacing the manual `acm_certificate_arn` variable.

## Tasks

- [x] 1. Create terraform/modules/dns/ module
  - [x] 1.1 Create terraform/modules/dns/variables.tf
    - Declare `domain_name`, `alb_dns_name` (with non-empty validation), `alb_zone_id`, `environment`, `project`
    - _Requirements: 6.2, 6.4_

  - [x] 1.2 Create terraform/modules/dns/main.tf
    - `aws_route53_zone.main` — public hosted zone tagged with project/environment
    - `aws_acm_certificate.main` — DNS validation, `create_before_destroy` lifecycle
    - `aws_route53_record.cert_validation` — for_each over domain_validation_options
    - `aws_acm_certificate_validation.main` — waits for ISSUED state
    - `aws_route53_record.alias` — A alias record pointing to ALB
    - _Requirements: 1.1, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

  - [x] 1.3 Create terraform/modules/dns/outputs.tf
    - Expose `hosted_zone_id`, `name_servers`, `certificate_arn` (from validation resource)
    - _Requirements: 2.4, 5.1, 6.3_

- [x] 2. Update root module
  - [x] 2.1 Update terraform/variables.tf
    - Add `var.domain_name` (string, default `"portal.glaciar.org"`)
    - Remove `var.acm_certificate_arn`
    - _Requirements: 4.3_

  - [x] 2.2 Update terraform/main.tf
    - Add `module "dns"` block wired to `module.alb` outputs
    - Pass `module.dns.certificate_arn` to `module.alb.acm_certificate_arn`
    - Set `app_base_url = "https://${var.domain_name}"` in `module.ecs`
    - Remove `var.acm_certificate_arn` reference
    - _Requirements: 4.1, 4.2_

  - [x] 2.3 Update terraform/outputs.tf
    - Add `portal_nameservers` output from `module.dns.name_servers` with description
    - _Requirements: 5.1, 5.2_

  - [x] 2.4 Update terraform/terraform.tfvars.example
    - Remove `acm_certificate_arn`, add `domain_name`
    - _Requirements: 4.3_

- [x] 3. Final checkpoint
  - Ensure all files are consistent, `terraform validate` passes, ask the user if questions arise.
