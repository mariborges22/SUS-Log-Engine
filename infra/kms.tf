data "aws_caller_identity" "current" {}

resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda environment variables"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.etl_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "nexus-sus-lambda-kms-${var.environment}"
    Environment = var.environment
    Project     = "Nexus-SUS"
  }
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/nexus-sus-lambda-${var.environment}"
  target_key_id = aws_kms_key.lambda.key_id
}
