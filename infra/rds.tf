# RDS Multi-AZ PostgreSQL
resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-db-${var.environment}"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp3"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.admin_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  multi_az             = true
  storage_encrypted    = true
  skip_final_snapshot  = true
  publicly_accessible  = false

  backup_retention_period = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "Main DB Subnet Group" }
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
