@"
terraform {
  backend "s3" {
    bucket         = "nexus-sus-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nexus-sus-terraform-lock"
    encrypt        = true
  }
}
"@ | Out-File -FilePath backend.tf -Encoding UTF8
