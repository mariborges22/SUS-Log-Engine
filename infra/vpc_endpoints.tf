# ==============================================================================
# VPC ENDPOINTS
# Permite acesso privado a serviços AWS sem passar pela Internet (ex: S3)
# Essencial para Lambdas em subnets privadas sem NAT Gateway
# ==============================================================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.existing_prod.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Associa à Route Table Principal (usada pelas subnets privadas)
  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-vpce-${var.environment}"
  }
}
