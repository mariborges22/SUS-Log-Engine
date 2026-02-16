# ==============================================================================
# AWS SECRETS MANAGER
# Armazena credenciais do banco de dados de forma segura
# ==============================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}/db-credentials/${var.environment}"
  description = "Credenciais do PostgreSQL RDS para o Nexus-SUS"
  kms_key_id  = aws_kms_key.lambda.arn

  tags = {
    Name        = "${var.project_name}-db-credentials-${var.environment}"
    Environment = var.environment
    Project     = "Nexus-SUS"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.admin_password
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = aws_db_instance.postgres.db_name
    engine   = "postgres"
  })
}
