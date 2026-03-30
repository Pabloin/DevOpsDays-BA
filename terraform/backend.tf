terraform {
  backend "s3" {
    bucket  = "backstage-portal-tfstate"
    key     = "mvp/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    use_lockfile = true
  }
}
