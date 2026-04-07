output "cluster_arn" {
  description = "ARN of the ECS Fargate cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS Fargate cluster"
  value       = aws_ecs_cluster.main.name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn_https" {
  description = "ARN of the HTTPS listener — services attach listener rules to this"
  value       = aws_lb_listener.https.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group — ECS task SGs need ingress from this"
  value       = aws_security_group.alb.id
}

output "wildcard_cert_arn" {
  description = "ARN of the validated wildcard ACM certificate"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID for {env}.glaciar.org"
  value       = aws_route53_zone.env.zone_id
}

output "name_servers" {
  description = "NS records for {env}.glaciar.org — add these as NS delegation in the glaciar.org registrar"
  value       = aws_route53_zone.env.name_servers
}

output "subdomain" {
  description = "The environment subdomain (e.g. dev.glaciar.org)"
  value       = local.subdomain
}
