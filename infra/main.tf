# ==============================================================================
# NEXUS-SUS TERRAFORM MAIN CONFIGURATION
# Infraestrutura AWS para processamento de alta performance com Hash Tables e B-Trees
# ==============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 para state remoto (configurar via GitHub Actions)
  # backend "s3" {
  #   bucket         = "nexus-sus-terraform-state"
  #   key            = "infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "nexus-sus-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ==============================================================================
# VPC CONFIGURATION
# ==============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (Frontend/API)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Private Subnets (RDS/Engine)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Security Group - Frontend (Porta 80)
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Security group para o Frontend Nexus-SUS (porta 80)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-sg"
  }
}

# Security Group - API Go (Porta 8080)
resource "aws_security_group" "api" {
  name        = "${var.project_name}-api-sg"
  description = "Security group para a API Go Nexus-SUS (porta 8080)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API access from Frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description = "API access from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-api-sg"
  }
}

# Security Group - RDS PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group para RDS PostgreSQL com PostGIS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  ingress {
    description = "PostgreSQL from VPC (Engine/ETL)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ==============================================================================
# AMAZON ECR - REPOSITÓRIOS PARA IMAGENS DEBIAN SLIM
# ==============================================================================

resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.ecr_repositories)
  name                 = each.value
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = each.value
    ImageBase   = "Debian-Slim"
    Performance = "High-Performance"
  }
}

# Lifecycle Policy para ECR (manter últimas 30 imagens)
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter últimas 30 imagens tagueadas"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "prod", "staging"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remover imagens não tagueadas após 7 dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==============================================================================
# RDS POSTGRESQL COM POSTGIS
# ==============================================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-postgres-params"
  family = "postgres15"

  # Parâmetros otimizados para alta performance com Hash Tables e B-Trees
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4096}"
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory*3/4096}"
  }

  parameter {
    name  = "work_mem"
    value = "65536" # 64MB - otimizado para operações de índice
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "131072" # 128MB - para criação de índices B-Tree
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1" # Otimizado para SSD
  }

  parameter {
    name  = "effective_io_concurrency"
    value = "200" # Alto para operações paralelas
  }

  tags = {
    Name = "${var.project_name}-postgres-params"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-postgres"

  # Engine Configuration
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # Single AZ para t3.micro (custo)

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Backup Configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Performance Insights
  performance_insights_enabled = false # Não disponível em t3.micro

  # Deletion Protection
  deletion_protection = false # Definir como true em produção
  skip_final_snapshot = true  # Definir como false em produção

  tags = {
    Name              = "${var.project_name}-postgres"
    PostGIS           = "Enabled"
    GeoMetadata       = "SUS-Geographic"
    PerformanceTarget = "O1-OLogN"
  }
}

# ==============================================================================
# S3 DATA LAKE - INGESTÃO DE LOGS BRUTOS
# ==============================================================================

resource "aws_s3_bucket" "data_lake" {
  bucket = "nexus-sus-data-lake"

  tags = {
    Name        = "nexus-sus-data-lake"
    Purpose     = "Raw-Log-Ingestion"
    Module      = "ETL-Python"
    Environment = var.environment
  }
}

# Versionamento para auditoria e recuperação de logs
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia server-side para dados sensíveis do SUS
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Bloquear acesso público ao Data Lake
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rules para gerenciamento de custos
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    filter {
      prefix = "raw-logs/"
    }

    # Mover para IA após 30 dias
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Mover para Glacier após 90 dias
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Expirar após 365 dias
    expiration {
      days = 365
    }
  }

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ==============================================================================
# IAM - POLÍTICAS PARA O MÓDULO ETL (PYTHON)
# ==============================================================================

# IAM Role para o ETL Python
resource "aws_iam_role" "etl_role" {
  name = "${var.project_name}-etl-role"

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

# Policy para leitura do S3 Data Lake
resource "aws_iam_policy" "etl_s3_read" {
  name        = "${var.project_name}-etl-s3-read-policy"
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

  tags = {
    Name   = "${var.project_name}-etl-s3-read-policy"
    Module = "ETL-Python"
  }
}

# Policy para escrita no S3 (dados processados)
resource "aws_iam_policy" "etl_s3_write" {
  name        = "${var.project_name}-etl-s3-write-policy"
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

  tags = {
    Name   = "${var.project_name}-etl-s3-write-policy"
    Module = "ETL-Python"
  }
}

# Policy para acesso ao ECR (pull de imagens)
resource "aws_iam_policy" "etl_ecr_access" {
  name        = "${var.project_name}-etl-ecr-access-policy"
  description = "Permite ao módulo ETL Python fazer pull de imagens do ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
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
        Resource = aws_ecr_repository.repos["nexus-sus-etl"].arn
      }
    ]
  })

  tags = {
    Name   = "${var.project_name}-etl-ecr-access-policy"
    Module = "ETL-Python"
  }
}

# Anexar policies ao role do ETL
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

# CloudWatch Logs para ETL
resource "aws_iam_role_policy_attachment" "etl_cloudwatch" {
  role       = aws_iam_role.etl_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ==============================================================================
# OUTPUTS CONSOLIDATION (ver outputs.tf para detalhes)
# ==============================================================================
