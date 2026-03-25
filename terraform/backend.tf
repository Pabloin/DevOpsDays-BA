terraform {
  backend "s3" {
    # Replace with the S3 bucket name created by terraform/bootstrap/
    # e.g. "backstage-tfstate"
    bucket = "<project>-tfstate"

    # Path within the bucket for this state file
    key = "mvp/terraform.tfstate"

    # AWS region where the S3 bucket and DynamoDB table live
    # e.g. "us-east-1"
    region = "<aws_region>"

    # Encrypt state at rest using SSE-S3
    encrypt = true

    # Replace with the DynamoDB table name created by terraform/bootstrap/
    # e.g. "backstage-tfstate-lock"
    dynamodb_table = "<project>-tfstate-lock"
  }
}
