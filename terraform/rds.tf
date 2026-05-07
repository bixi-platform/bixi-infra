# Provisioned only when enable_rds = true (not used in LocalStack testing).

resource "aws_db_subnet_group" "main" {
  count      = var.enable_rds ? 1 : 0
  name       = "${local.name_prefix}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${local.name_prefix}-rds"
  description = "Allow PostgreSQL from ECS tasks and Lambda"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  count = var.enable_rds ? 1 : 0

  identifier        = "${local.name_prefix}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage_gb
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  # No Multi-AZ in dev; set to true for production
  multi_az            = var.env == "prod"
  publicly_accessible = false
  skip_final_snapshot = var.env != "prod"

  backup_retention_period = var.env == "prod" ? 7 : 1
  deletion_protection     = var.env == "prod"

  # Migrations are run separately via bixi-infra/Makefile migrate-aws
  # Never let Terraform manage the schema.
}
