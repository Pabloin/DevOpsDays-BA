output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Nameservers for the hosted zone — add these as an NS record for the subdomain in the registrar account"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated ACM certificate (only resolves after cert reaches ISSUED state)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "hosted_zone_arn" {
  description = "ARN of the Route53 hosted zone"
  value       = aws_route53_zone.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB (resolved via data source)"
  value       = local.alb_dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  value       = local.alb_zone_id
}
