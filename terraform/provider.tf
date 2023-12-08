provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  profile             = var.profile
}

terraform {
  required_version = "1.3.4"
  backend "s3" {}
}
