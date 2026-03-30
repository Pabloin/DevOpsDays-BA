output "tfstate_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state storage"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state storage"
  value       = aws_s3_bucket.tfstate.arn
}
