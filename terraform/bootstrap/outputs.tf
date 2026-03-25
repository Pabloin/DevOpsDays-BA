output "tfstate_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state storage"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state storage"
  value       = aws_s3_bucket.tfstate.arn
}

output "tfstate_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "tfstate_lock_table_arn" {
  description = "ARN of the DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.tfstate_lock.arn
}
