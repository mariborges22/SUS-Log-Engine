# ==============================================================================
# NEXUS-SUS TERRAFORM VARIABLES
# Infraestrutura AWS para o ecossistema de processamento de alta performance
# ==============================================================================

variable "aws_region" {
  description = "Região AWS para deploy da infraestrutura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto para tagueamento de recursos"
  type        = string
  default     = "nexus-sus"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ==============================================================================
# DATABASE CONFIGURATION
# ==============================================================================

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "nexus_sus_db"
}

variable "db_username" {
  description = "Username do administrador do banco"
  type        = string
  default     = "nexus_admin"
  sensitive   = true
}

variable "admin_password" {
  description = "Senha do administrador do banco (injetada via GitHub Actions)"
  type        = string
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado para RDS em GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Armazenamento máximo para autoscaling do RDS em GB"
  type        = number
  default     = 100
}

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks para subnets públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks para subnets privadas (RDS)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ==============================================================================
# ECR CONFIGURATION
# ==============================================================================

variable "ecr_repositories" {
  description = "Lista de repositórios ECR para as imagens Debian Slim"
  type        = list(string)
  default = [
    "nexus-sus-engine",
    "nexus-sus-api",
    "nexus-sus-etl",
    "nexus-sus-frontend"
  ]
}

variable "ecr_image_tag_mutability" {
  description = "Mutabilidade das tags de imagem (MUTABLE ou IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Habilitar scan de vulnerabilidades no push"
  type        = bool
  default     = true
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "common_tags" {
  description = "Tags comuns aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project     = "Nexus-SUS"
    ManagedBy   = "Terraform"
    Repository  = "SUS-Log-Engine"
    Performance = "High-Performance-O1-OLogN"
  }
}
