locals {
  tags = {
    Environment = var.environment
    Project     = var.project
  }
  # Use explicit variable values when provided; otherwise fall back to data source.
  # This allows the module to be called without alb_dns_name/alb_zone_id in the root
  # module (breaking the module cycle), while still accepting them for direct use.
  alb_dns_name = var.alb_dns_name != null ? var.alb_dns_name : data.aws_lb.main.dns_name
  alb_zone_id  = var.alb_zone_id != null ? var.alb_zone_id : data.aws_lb.main.zone_id
}

# ─── ALB lookup (breaks module cycle: dns ↔ alb) ─────────────────────────────
# The ALB is created by the alb module. We look it up by name so this module
# does not depend on module.alb at the Terraform graph level, avoiding a cycle
# (module.alb needs module.dns.certificate_arn; module.dns needs the ALB DNS name).

data "aws_lb" "main" {
  name = "${var.project}-${var.environment}-alb"
}

# ─── Hosted Zone ─────────────────────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-hz"
  })
}

# ─── ACM Certificate ─────────────────────────────────────────────────────────

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ─── CNAME Validation Records ────────────────────────────────────────────────

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# ─── Certificate Validation Waiter ───────────────────────────────────────────

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ─── Alias Record → ALB ──────────────────────────────────────────────────────

resource "aws_route53_record" "alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = local.alb_dns_name
    zone_id                = local.alb_zone_id
    evaluate_target_health = true
  }
}
