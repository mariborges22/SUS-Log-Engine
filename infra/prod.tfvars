project_name = "nexus-sus"
environment  = "prod"
aws_region   = "us-east-1"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

db_name     = "nexus_sus_db"
db_username = "admin_user"
# admin_password will be passed via TF_VAR or Secret Manager

common_tags = {
  Project     = "Nexus-SUS"
  Environment = "Production"
  Owner       = "Senior Architecture Team"
}
