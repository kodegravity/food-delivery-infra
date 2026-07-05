resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.environment}-db-subnet-group"
  description = "DB subnet group for ${var.project} ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-postgres"
  })
}

# Store all DB credentials in a single Secrets Manager secret as JSON
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project}/${var.environment}/db/credentials"
  description = "PostgreSQL credentials for ${var.project} ${var.environment}"

  recovery_window_in_days = 0 # Immediate deletion in dev

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = tostring(aws_db_instance.main.port)
    dbname   = var.db_name
    url      = "jdbc:postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
  })
}
