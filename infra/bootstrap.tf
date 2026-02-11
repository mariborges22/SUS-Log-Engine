# ==============================================================================
# NEXUS-SUS BOOTSTRAP - INFRAESTRUTURA DE SUPORTE
# Este arquivo cria os recursos necessários para o State Remoto e Lock.
# ==============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "nexus-sus-terraform-state"
  
  # Proteção contra deleção para evitar perda do histórico da infra
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "Nexus-SUS-Terraform-State"
    Environment = "Prod"
    ManagedBy   = "Terraform-Bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "nexus-sus-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Nexus-SUS-Terraform-Locks"
    Environment = "Prod"
    ManagedBy   = "Terraform-Bootstrap"
  }
}
