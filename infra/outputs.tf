# ==============================================================================
# NEXUS-SUS TERRAFORM OUTPUTS
# Valores exportados para injeção no GitHub Actions e binário C++
# ==============================================================================

# ==============================================================================
# ECR REPOSITORY URLS
# URLs para push das imagens Debian Slim via GitHub Actions
# ==============================================================================

output "ecr_repository_urls" {
  description = "Map de URLs dos repositórios ECR para todas as imagens"
  value = {
    for repo_name, repo in aws_ecr_repository.repos :
    repo_name => repo.repository_url
  }
}

output "ecr_engine_url" {
  description = "URL do repositório ECR para o Engine C++ (Hash Tables/B-Trees)"
  value       = aws_ecr_repository.repos["nexus-sus-engine"].repository_url
}

output "ecr_api_url" {
  description = "URL do repositório ECR para a API Go"
  value       = aws_ecr_repository.repos["nexus-sus-api"].repository_url
}

output "ecr_etl_url" {
  description = "URL do repositório ECR para o ETL Pipeline"
  value       = aws_ecr_repository.repos["nexus-sus-etl"].repository_url
}

output "ecr_frontend_url" {
  description = "URL do repositório ECR para o Frontend"
  value       = aws_ecr_repository.repos["nexus-sus-frontend"].repository_url
}

output "ecr_registry_id" {
  description = "ID do registry ECR (Account ID)"
  value       = data.aws_caller_identity.current.account_id
}

# ==============================================================================
# RDS DATABASE ENDPOINTS
# Endpoints para conexão do Engine C++ e API Go
# ==============================================================================

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_hostname" {
  description = "Hostname do RDS PostgreSQL (sem porta)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Porta do RDS PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "Username do administrador do banco"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

# ==============================================================================
# DATABASE CONNECTION STRING
# String de conexão formatada para injeção no binário C++
# ==============================================================================

output "database_connection_string" {
  description = "Connection string PostgreSQL para o Engine C++ (sem senha)"
  value       = "postgresql://${aws_db_instance.postgres.username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}

output "database_connection_string_template" {
  description = "Template da connection string (substituir PASSWORD)"
  value       = "postgresql://${aws_db_instance.postgres.username}:PASSWORD@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=require"
  sensitive   = true
}

# ==============================================================================
# NETWORK OUTPUTS
# Informações de rede para referência
# ==============================================================================

output "vpc_id" {
  description = "ID da VPC Nexus-SUS"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas (Frontend/API)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas (RDS/Engine)"
  value       = aws_subnet.private[*].id
}

# ==============================================================================
# SECURITY GROUP IDS
# Para referência em outros deployments
# ==============================================================================

output "frontend_security_group_id" {
  description = "ID do Security Group do Frontend (porta 80)"
  value       = aws_security_group.frontend.id
}

output "api_security_group_id" {
  description = "ID do Security Group da API (porta 8080)"
  value       = aws_security_group.api.id
}

output "rds_security_group_id" {
  description = "ID do Security Group do RDS"
  value       = aws_security_group.rds.id
}

# ==============================================================================
# ECS CLUSTER & SERVICES
# ==============================================================================

output "ecs_cluster_name" {
  description = "Nome do Cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_api_name" {
  description = "Nome do Serviço ECS para a API"
  value       = aws_ecs_service.api.name
}

output "ecs_service_frontend_name" {
  description = "Nome do Serviço ECS para o Frontend"
  value       = aws_ecs_service.frontend.name
}

# ==============================================================================
# GITHUB ACTIONS ENVIRONMENT VARIABLES
# Bloco formatado para copiar direto no workflow
# ==============================================================================

output "github_actions_env_block" {
  description = "Bloco de variáveis de ambiente para GitHub Actions"
  value = <<-EOT
    # ============================================
    # NEXUS-SUS AWS INFRASTRUCTURE OUTPUTS
    # Cole estas variáveis no seu GitHub Actions
    # ============================================
    ECR_REGISTRY: ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    ECR_ENGINE_REPO: ${aws_ecr_repository.repos["nexus-sus-engine"].name}
    ECR_API_REPO: ${aws_ecr_repository.repos["nexus-sus-api"].name}
    ECR_ETL_REPO: ${aws_ecr_repository.repos["nexus-sus-etl"].name}
    ECR_FRONTEND_REPO: ${aws_ecr_repository.repos["nexus-sus-frontend"].name}
    RDS_ENDPOINT: ${aws_db_instance.postgres.address}
    RDS_PORT: ${aws_db_instance.postgres.port}
    RDS_DATABASE: ${aws_db_instance.postgres.db_name}
  EOT
}

# ==============================================================================
# C++ ENGINE BUILD FLAGS
# Flags para compilação do binário C++ com informações da infra
# ==============================================================================

output "cpp_engine_build_flags" {
  description = "Flags de compilação para injetar no Engine C++"
  value = {
    DB_HOST     = aws_db_instance.postgres.address
    DB_PORT     = tostring(aws_db_instance.postgres.port)
    DB_NAME     = aws_db_instance.postgres.db_name
    DB_USER     = aws_db_instance.postgres.username
    AWS_REGION  = var.aws_region
    ECR_REPO    = aws_ecr_repository.repos["nexus-sus-engine"].repository_url
  }
  sensitive = true
}

# ==============================================================================
# S3 DATA LAKE OUTPUTS
# Informações do bucket para o módulo ETL Python
# ==============================================================================

output "s3_data_lake_bucket_name" {
  description = "Nome do bucket S3 Data Lake para logs brutos"
  value       = aws_s3_bucket.data_lake.id
}

output "s3_data_lake_bucket_arn" {
  description = "ARN do bucket S3 Data Lake"
  value       = aws_s3_bucket.data_lake.arn
}

output "s3_data_lake_bucket_domain" {
  description = "Domain name do bucket S3 Data Lake"
  value       = aws_s3_bucket.data_lake.bucket_regional_domain_name
}

# ==============================================================================
# IAM OUTPUTS
# ARNs para configuração do módulo ETL
# ==============================================================================

output "etl_role_arn" {
  description = "ARN da IAM Role para o módulo ETL Python"
  value       = aws_iam_role.etl_role.arn
}

output "etl_role_name" {
  description = "Nome da IAM Role para o módulo ETL Python"
  value       = aws_iam_role.etl_role.name
}

output "etl_s3_read_policy_arn" {
  description = "ARN da policy de leitura S3 para ETL"
  value       = aws_iam_policy.etl_s3_read.arn
}

# ==============================================================================
# ETL MODULE CONFIGURATION
# Configuração completa para o módulo ETL Python
# ==============================================================================

output "etl_config" {
  description = "Configuração completa para o módulo ETL Python"
  value = {
    role_arn         = aws_iam_role.etl_role.arn
    s3_bucket        = aws_s3_bucket.data_lake.id
    s3_bucket_arn    = aws_s3_bucket.data_lake.arn
    raw_logs_prefix  = "raw-logs/"
    processed_prefix = "processed/"
    ecr_repo_url     = aws_ecr_repository.repos["nexus-sus-etl"].repository_url
    aws_region       = var.aws_region
  }
}

