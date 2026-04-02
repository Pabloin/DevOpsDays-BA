# Design Document: Scaffolder DNS Records (`09-scaffolder-dns-records`)

## Overview

Enhance the AI Ops Assistant template to automatically create Route53 DNS records and ACM certificate updates when users scaffold a new app. Each scaffolded app gets a subdomain like `{service_name}.backstage.glaciar.org` pointing to the main ALB.

## Architecture

```
Backstage Portal (portal.glaciar.org)
        ↓
    User scaffolds "demo3" template
        ↓
    Scaffolder step: create-dns-record
        ├─ Add Route53 record: demo3.backstage.glaciar.org → ALB
        └─ Update ACM cert SAN: portal.glaciar.org + demo3.backstage.glaciar.org + ...
        ↓
    Both domains serve same Backstage instance (ALB → ECS)
```

## Changes

### 1. Template Enhancement

**File:** `backstage-portal/examples/template/ai-ops-assistant/template.yaml`

Add new parameter to scaffold form:

```yaml
- title: Domain configuration
  properties:
    custom_domain:
      title: Custom domain
      type: string
      description: Optional. Full domain like "demo3.backstage.glaciar.org"
      default: ""
      pattern: '^([a-z0-9-]*\.)?backstage\.glaciar\.org$|^$'
      ui:help: Leave empty to skip DNS setup
```

Add new scaffolder step after `publish:github`:

```yaml
- id: create-dns
  name: Create DNS record (optional)
  if: ${{ parameters.custom_domain }}
  action: scaffold:custom-dns
  input:
    domain: ${{ parameters.custom_domain }}
    service_name: ${{ parameters.service_name }}
    repository_url: ${{ steps.publish.output.remoteUrl }}
```

### 2. Custom Action Implementation

Create a custom Backstage action (in the Backstage app itself or via plugin) that:

1. **Calls AWS API** to create Route53 record
   - Uses OIDC credentials from GitHub Actions
   - Creates alias record pointing to ALB

2. **Updates ACM certificate**
   - Adds domain as SAN to existing certificate
   - Terraform in root module handles DNS validation

3. **Triggers CI/CD**
   - Posts to GitHub Actions webhook or creates a commit
   - Root Terraform apply picks up new certificate/DNS changes

### Alternative: Generated Terraform Approach

**File:** Generated app repo includes `terraform/dns.tf`

```hcl
variable "custom_domain" {
  type = string
  default = "demo3.backstage.glaciar.org"
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = data.aws_lb.main.dns_name
    zone_id                = data.aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

Then generated CI/CD (GitHub Actions) runs `terraform apply` to create the record.

**Limitation:** Does not update the ACM certificate in the root module. Would need:
- Shared Terraform state or
- API call to update root module's certificate SANs

## Decision: Custom Action + Webhook

**Simpler approach:**

1. Template captures `custom_domain` parameter
2. After GitHub publish, scaffolder calls custom action `scaffold:create-dns-record`
3. Action makes HTTP POST to a Lambda/webhook in the main AWS account
4. Lambda:
   - Creates Route53 record
   - Triggers root module Terraform apply with new SAN list
5. Terraform handles certificate validation

**Advantages:**
- Centralized control (root module owns all DNS/certs)
- No separate state management
- One Terraform apply handles everything

**Trade-off:** Requires Lambda or webhook endpoint in AWS account (new infrastructure).

## Implementation Steps

1. Add parameter to template YAML
2. Create custom Backstage action handler
3. Create Lambda/webhook to handle DNS creation
4. Update root Terraform to accept SANs variable
5. Test end-to-end scaffolding with custom domain
6. Document in template README

## Testing Flow

```
1. User scaffolds "demo3"
2. Provides custom_domain = "demo3.backstage.glaciar.org"
3. Template publishes to GitHub
4. Custom action calls Lambda
5. Lambda creates Route53 record + updates cert
6. 5-10 min later: dig demo3.backstage.glaciar.org → resolves ✓
7. curl -I https://demo3.backstage.glaciar.org → 200 ✓
```
