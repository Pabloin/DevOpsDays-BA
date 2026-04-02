# Requirements: Scaffolder DNS Record Creation (`09-scaffolder-dns-records`)

## Goal

When users scaffold a new AI Ops Assistant using the Backstage template, automatically create a Route53 DNS record for the app (e.g., `{service_name}.backstage.glaciar.org`) and add it to the ACM certificate, enabling the scaffolded app to be served under a custom subdomain.

## Functional Requirements

| Req | Title | Description |
|-----|-------|-------------|
| 1.1 | DNS record creation action | Add a new Backstage scaffolder step that creates Route53 records via AWS API |
| 1.2 | Record naming | Record should follow pattern `{service_name}.backstage.glaciar.org` |
| 1.3 | Points to ALB | The alias record points to the same ALB as the main portal |
| 1.4 | ACM certificate update | Add the new domain to ACM certificate as SAN automatically |
| 1.5 | HTTPS validation | Terraform/AWS handles DNS validation for the new SAN |
| 2.1 | Template enhancement | Template form captures domain requirement, passes to scaffolder step |
| 2.2 | GitHub Actions integration | CI/CD should handle Terraform apply for DNS + certificate update |
| 2.3 | Documented | Template README explains the DNS auto-setup feature |

## Non-Functional Requirements

| Req | Title | Description |
|-----|-------|-------------|
| 3.1 | Eventual consistency | DNS propagation may take 5-10 minutes; document in template |
| 3.2 | Idempotent | Creating same app twice should not fail (Terraform handles) |
| 3.3 | Backward compatible | Existing apps without DNS records still work |

## Acceptance Criteria

- [ ] Template form has optional field: "Custom domain?" (defaults to `{service_name}.backstage.glaciar.org`)
- [ ] Scaffolder adds custom `scaffold:terraform` action that applies DNS + cert changes
- [ ] Generated app repo includes Terraform to create Route53 record + update cert
- [ ] DNS record resolves after apply
- [ ] HTTPS works with valid certificate
- [ ] Template README documents the feature
