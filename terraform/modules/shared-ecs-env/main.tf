locals {
  # e.g. "dev.backstage.glaciar.org" or "prod.backstage.glaciar.org"
  subdomain = "${var.environment}.${var.base_domain}"

  # ALB name has a 32-char AWS limit — keep it short
  alb_name = "apps-${var.environment}-alb"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ─── ACM Certificate (wildcard for *.{env}.backstage.glaciar.org) ─────────────
# DNS validation records go into the existing backstage.glaciar.org zone —
# no NS delegation needed, cert validates immediately.

resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${local.subdomain}"
  validation_method = "DNS"

  tags = merge(local.tags, {
    Name = "${var.project}-apps-${var.environment}-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ─── ALB Security Group ───────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.project}-apps-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS from internet to apps ${var.environment} ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project}-apps-${var.environment}-alb-sg"
  })
}

# ─── Application Load Balancer ───────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = merge(local.tags, {
    Name = local.alb_name
  })
}

# HTTP listener — redirect all to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project}-apps-${var.environment}-http-listener"
  })
}

# HTTPS listener — default 404 (services attach their own listener rules)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.wildcard.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "no service found"
      status_code  = "404"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.project}-apps-${var.environment}-https-listener"
  })
}

# ─── Route53 Wildcard Alias Record ───────────────────────────────────────────
# *.{env}.backstage.glaciar.org → ALB
# Goes into the existing backstage.glaciar.org hosted zone.

resource "aws_route53_record" "wildcard" {
  zone_id = var.route53_zone_id
  name    = "*.${local.subdomain}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ─── ECS Fargate Cluster ─────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-apps-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.tags, {
    Name = "${var.project}-apps-${var.environment}"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = var.environment == "dev" ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = var.environment == "dev" ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
    base              = 1
  }
}
