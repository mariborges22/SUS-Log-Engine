# ==============================================================================
# ETL LAMBDA FUNCTION
# Execução Serverless dentro da VPC
# ==============================================================================

# Security Group para a Lambda
resource "aws_security_group" "etl_lambda" {
  name        = "${var.project_name}-etl-lambda-sg-${var.environment}"
  description = "Security Group para a Lambda de ETL"
  vpc_id      = aws_vpc.main.id

  # Egress para tudo (baixar pacotes, conectar no S3, etc)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-etl-lambda-sg-${var.environment}"
  }
}

# Permite que a Lambda acesse o RDS
resource "aws_security_group_rule" "rds_allow_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.etl_lambda.id
  security_group_id        = aws_security_group.rds.id
}

# Permissão para a Lambda criar interfaces de rede na VPC
resource "aws_iam_role_policy_attachment" "etl_vpc_access" {
  role       = aws_iam_role.etl_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Recurso Lambda
resource "aws_lambda_function" "etl" {
  function_name = "${var.project_name}-etl-${var.environment}"
  role          = aws_iam_role.etl_role.arn
  handler       = "extrair_sus.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300 # 5 min timeout
  memory_size   = 512

  # Dummy filename inicial (o código real vem do GitHub Actions)
  # O Terraform precisa de um arquivo ZIP inicial válido
  filename      = "${path.module}/dummy_lambda.zip" 

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.etl_lambda.id]
  }

  environment {
    variables = {
      DB_HOST         = aws_db_instance.postgres.address
      DB_NAME         = aws_db_instance.postgres.db_name
      DB_USER         = var.db_username
      DB_PASSWORD     = var.admin_password
      S3_BUCKET_NAME  = aws_s3_bucket.data_lake.id
    }
  }

  lifecycle {
    ignore_changes = [
      filename, 
      source_code_hash # Ignora mudanças de código (gerenciado pelo GitHub Actions)
    ]
  }
}

# Criar um ZIP dummy se não existir (para o Terraform plan não falhar localmente ou no primeiro run)
data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/dummy_lambda.zip"
  
  source_content = "def lambda_handler(event, context): return 'hello'"
  source_content_filename = "extrair_sus.py"
}
