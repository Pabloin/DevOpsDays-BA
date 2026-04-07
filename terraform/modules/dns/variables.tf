variable "domain_name" {
  description = "FQDN for the portal subdomain (e.g. backstage.glaciar.org)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB. When provided, overrides the data source lookup. Must not be empty if set."
  type        = string
  default     = null
  validation {
    condition     = var.alb_dns_name == null || try(length(var.alb_dns_name) > 0, false)
    error_message = "alb_dns_name must not be empty."
  }
}

variable "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB. When provided, overrides the data source lookup."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}
