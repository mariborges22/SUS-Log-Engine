# ==============================================================================
# S3 DATA LAKE - INGESTÃO DE LOGS BRUTOS
# ==============================================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = "nexus-sus-data-lake-${var.environment}"

  tags = {
    Name        = "nexus-sus-data-lake"
    Purpose     = "Raw-Log-Ingestion"
    Module      = "ETL-Python"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  rule {
    id     = "archive-old-logs"
    status = "Enabled"
    filter {
      prefix = "raw-logs/"
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }
}

# ==============================================================================
# IAM - POLÍTICAS PARA O MÓDULO ETL (PYTHON)
# ==============================================================================

resource "aws_iam_role" "etl_role" {
  name = "${var.project_name}-etl-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name   = "${var.project_name}-etl-role"
    Module = "ETL-Python"
  }
}

resource "aws_iam_policy" "etl_s3_read" {
  name        = "${var.project_name}-etl-s3-read-policy-${var.environment}"
  description = "Permite ao módulo ETL Python ler do bucket S3 Data Lake"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.data_lake.arn
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging"
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/*"
      }
    ]
  })
}

resource "aws_iam_policy" "etl_s3_write" {
  name        = "${var.project_name}-etl-s3-write-policy-${var.environment}"
  description = "Permite ao módulo ETL Python escrever dados processados no S3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/processed/*"
      }
    ]
  })
}

resource "aws_iam_policy" "etl_ecr_access" {
  name        = "${var.project_name}-etl-ecr-access-policy-${var.environment}"
  description = "Permite ao módulo ETL Python fazer pull de imagens do ECR"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*" # Ajustado para permitir pull de qualquer repo necessário pelo ETL
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "etl_s3_read" {
  role       = aws_iam_role.etl_role.name
  policy_arn = aws_iam_policy.etl_s3_read.arn
}

resource "aws_iam_role_policy_attachment" "etl_s3_write" {
  role       = aws_iam_role.etl_role.name
  policy_arn = aws_iam_policy.etl_s3_write.arn
}

resource "aws_iam_role_policy_attachment" "etl_ecr_access" {
  role       = aws_iam_role.etl_role.name
  policy_arn = aws_iam_policy.etl_ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "etl_cloudwatch" {
  role       = aws_iam_role.etl_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "etl_kms_decrypt" {
  name   = "${var.project_name}-etl-kms-decrypt-${var.environment}"
  role   = aws_iam_role.etl_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}
