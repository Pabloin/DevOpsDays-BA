# Requirements Document

## Introduction

This feature configures `portal.glaciar.org` as the custom domain for the Backstage portal running on AWS (Chile account). It uses subdomain delegation: a Route 53 hosted zone for `portal.glaciar.org` is created in the Chile account, an ACM certificate is provisioned and DNS-validated via that hosted zone, and an alias record points the domain to the existing ALB. The nameservers output by Terraform must then be manually added as an NS delegation record in the `glaciar.org` zone in the separate registrar account.

All Terraform changes are scoped to the Chile deployment account only.

## Glossary

- **DNS_Module**: The new Terraform module at `terraform/modules/dns/` responsible for the hosted zone, ACM certificate, and alias record.
- **Hosted_Zone**: The Route 53 public hosted zone for `portal.glaciar.org` created in the Chile account.
- **ACM_Certificate**: The AWS Certificate Manager TLS certificate for `portal.glaciar.org`, validated via DNS records in the Hosted_Zone.
- **ALB**: The existing Application Load Balancer managed by `terraform/modules/alb/`, which already has an HTTPS listener accepting a certificate ARN.
- **Alias_Record**: The Route 53 A alias record that resolves `portal.glaciar.org` to the ALB.
- **NS_Delegation**: The NS record that must be manually added in the `glaciar.org` zone (separate AWS account) to delegate `portal.glaciar.org` to the Hosted_Zone nameservers.
- **Root_Module**: The root Terraform configuration at `terraform/main.tf`, `variables.tf`, and `outputs.tf`.

## Requirements

### Requirement 1: Route 53 Hosted Zone for the Portal Subdomain

**User Story:** As a platform engineer, I want a Route 53 hosted zone for `portal.glaciar.org` in the Chile account, so that I can manage DNS records for the portal subdomain independently of the registrar account.

#### Acceptance Criteria

1. THE DNS_Module SHALL create a Route 53 public Hosted_Zone for the domain specified by `var.domain_name` (default: `portal.glaciar.org`).
2. WHEN Terraform apply completes, THE Root_Module SHALL output the Hosted_Zone nameservers as `portal_nameservers` so the operator knows which NS values to add in the registrar account.
3. THE DNS_Module SHALL tag the Hosted_Zone with the project and environment tags consistent with other resources in the Root_Module.

---

### Requirement 2: ACM Certificate with DNS Validation

**User Story:** As a platform engineer, I want an ACM certificate for `portal.glaciar.org` validated via Route 53, so that the ALB can serve HTTPS traffic under the custom domain without manual validation steps.

#### Acceptance Criteria

1. THE DNS_Module SHALL create an ACM_Certificate for the domain specified by `var.domain_name` using DNS validation.
2. WHEN the ACM_Certificate is created, THE DNS_Module SHALL create the required CNAME validation records in the Hosted_Zone so that certificate validation completes automatically during `terraform apply`.
3. WHILE the ACM_Certificate validation is pending, THE DNS_Module SHALL use `aws_acm_certificate_validation` to wait for the certificate to reach the `ISSUED` state before exposing its ARN as an output.
4. THE DNS_Module SHALL expose the validated ACM_Certificate ARN as an output so the Root_Module can pass it to the ALB module.

---

### Requirement 3: Route 53 Alias Record Pointing to the ALB

**User Story:** As a platform engineer, I want `portal.glaciar.org` to resolve to the Backstage ALB, so that users can reach the portal via the custom domain.

#### Acceptance Criteria

1. THE DNS_Module SHALL create an Alias_Record of type A in the Hosted_Zone that resolves `var.domain_name` to the ALB DNS name.
2. THE DNS_Module SHALL accept the ALB DNS name and ALB hosted zone ID as input variables so it remains decoupled from the ALB module internals.
3. WHEN the Alias_Record is evaluated, THE DNS_Module SHALL use the ALB's canonical hosted zone ID (not a static string) to ensure correct alias routing.

---

### Requirement 4: ALB HTTPS Listener Wired to the ACM Certificate

**User Story:** As a platform engineer, I want the ALB HTTPS listener to use the ACM certificate for `portal.glaciar.org`, so that browsers receive a valid TLS certificate when accessing the portal.

#### Acceptance Criteria

1. THE Root_Module SHALL pass the ACM_Certificate ARN output from the DNS_Module to the ALB module's `acm_certificate_arn` input, replacing any previously manually supplied value.
2. WHEN `var.domain_name` is set, THE Root_Module SHALL set the ECS module's `app_base_url` to `https://${var.domain_name}` instead of the ALB DNS name.
3. THE Root_Module SHALL declare `var.domain_name` with type `string` and default value `"portal.glaciar.org"`.

---

### Requirement 5: Nameserver Output for Manual NS Delegation

**User Story:** As a platform engineer, I want Terraform to output the nameservers of the new hosted zone, so that I know exactly which NS records to add in the `glaciar.org` zone in the registrar account.

#### Acceptance Criteria

1. WHEN `terraform apply` or `terraform output` is run, THE Root_Module SHALL output the list of nameservers for the Hosted_Zone under the output name `portal_nameservers`.
2. THE Root_Module SHALL include a description on the `portal_nameservers` output explaining that these values must be added as an NS record for `portal.glaciar.org` in the registrar account.

---

### Requirement 6: DNS Module Interface and Structure

**User Story:** As a platform engineer, I want the DNS logic encapsulated in a dedicated module, so that it is easy to test, review, and reuse independently of other infrastructure modules.

#### Acceptance Criteria

1. THE DNS_Module SHALL be located at `terraform/modules/dns/` and contain at minimum `main.tf`, `variables.tf`, and `outputs.tf`.
2. THE DNS_Module SHALL accept the following input variables: `domain_name` (string), `alb_dns_name` (string), `alb_zone_id` (string), `environment` (string), `project` (string).
3. THE DNS_Module SHALL expose the following outputs: `hosted_zone_id` (string), `name_servers` (list of strings), `certificate_arn` (string).
4. IF the `alb_dns_name` variable is empty, THEN THE DNS_Module SHALL raise a Terraform validation error rather than creating a misconfigured Alias_Record.
