terraform {
  backend "s3" {
    bucket         = "nexus-sus-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nexus-sus-terraform-lock"
    encrypt        = true
  }
}
