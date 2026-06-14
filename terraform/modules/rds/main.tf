resource "aws_db_subnet_group" "this" {
  name        = var.identifier
  description = "Subnet group for ${var.identifier} RDS instance."
  subnet_ids  = var.database_subnet_ids

  tags = merge(var.tags, { Name = var.identifier })
}

resource "aws_db_parameter_group" "this" {
  name        = var.identifier
  family      = "postgres16"
  description = "Parameter group for ${var.identifier} enforcing SSL."

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(var.tags, { Name = var.identifier })
}

resource "aws_security_group" "rds" {
  name        = "${var.identifier}-rds"
  description = "Allow PostgreSQL access from private subnets only."
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.identifier}-rds" })
}

resource "aws_db_instance" "this" {
  identifier = var.identifier

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage  = var.allocated_storage
  storage_type       = "gp3"
  storage_encrypted  = true
  kms_key_id         = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible        = false
  multi_az                   = false
  skip_final_snapshot        = var.skip_final_snapshot
  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true

  backup_window      = "03:00-04:00"
  maintenance_window = "Mon:04:00-Mon:05:00"

  tags = merge(var.tags, { Name = var.identifier })
}
