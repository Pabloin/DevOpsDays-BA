locals {
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-db-subnet-group" })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL access from ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-rds-sg" })
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = var.rds_secret_arn
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-${var.environment}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "backstage"
  username = var.db_username
  password = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)["password"]

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  deletion_protection = false

  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-postgres" })
}
