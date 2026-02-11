variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nexus-sus"
}

variable "environment" {
  description = "Environment (prod/staging)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "nexus_sus_db"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    Project     = "Nexus-SUS"
    Owner       = "Senior Architecture Team"
  }
}

variable "ecr_repositories" {
  description = "List of ECR repo names"
  type        = list(string)
  default     = ["nexus-sus-api", "nexus-sus-frontend"]
}

data "aws_availability_zones" "available" {
  state = "available"
}
