terraform {
  backend "s3" {
    bucket         = "nexus-sus-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "nexus-sus-terraform-locks"
  }
}
