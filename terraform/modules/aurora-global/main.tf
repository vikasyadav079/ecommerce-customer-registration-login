###############################################################################
# Aurora Global PostgreSQL 16 Module
###############################################################################

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_id   = "${local.name_prefix}-aurora-pg"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# DB Subnet Group
###############################################################################

resource "aws_db_subnet_group" "aurora" {
  name        = "${local.cluster_id}-subnet-group"
  description = "Subnet group for Aurora PostgreSQL cluster"
  subnet_ids  = var.data_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-subnet-group"
  })
}

###############################################################################
# Aurora Parameter Groups
###############################################################################

resource "aws_rds_cluster_parameter_group" "aurora_pg16" {
  family      = "aurora-postgresql16"
  name        = "${local.cluster_id}-cluster-params"
  description = "Aurora PostgreSQL 16 cluster parameter group for CIAM"

  # Performance and connection settings
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgaudit,pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1 second
  }

  parameter {
    name  = "pgaudit.log"
    value = "write,ddl"
  }

  parameter {
    name  = "max_connections"
    value = "LEAST({DBInstanceClassMemory/9531392}, 5000)"
  }

  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "30000"  # 30 seconds
  }

  parameter {
    name  = "lock_timeout"
    value = "30000"
  }

  parameter {
    name  = "statement_timeout"
    value = "60000"  # 60 seconds
  }

  parameter {
    name  = "work_mem"
    value = "65536"  # 64MB
  }

  parameter {
    name  = "effective_cache_size"
    value = "3145728"  # 3GB
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "aurora_pg16_instance" {
  family      = "aurora-postgresql16"
  name        = "${local.cluster_id}-instance-params"
  description = "Aurora PostgreSQL 16 instance parameter group"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "auto_explain.log_min_duration"
    value = "5000"  # Log query plans for queries > 5 seconds
  }

  tags = var.tags
}

###############################################################################
# IAM Role for Enhanced Monitoring
###############################################################################

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0
  name  = "${local.cluster_id}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.enable_enhanced_monitoring ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

###############################################################################
# Aurora Global Database (Primary Cluster)
###############################################################################

resource "aws_rds_global_cluster" "main" {
  count                     = var.enable_global_db ? 1 : 0
  global_cluster_identifier = "${local.cluster_id}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.database_name
  deletion_protection       = var.deletion_protection
  storage_encrypted         = true
}

###############################################################################
# Aurora Primary Cluster
###############################################################################

resource "aws_rds_cluster" "primary" {
  cluster_identifier     = local.cluster_id
  engine                 = "aurora-postgresql"
  engine_version         = var.engine_version
  database_name          = var.database_name
  master_username        = var.master_username
  master_password        = var.master_password
  port                   = 5432

  # Global DB association
  global_cluster_identifier = var.enable_global_db ? aws_rds_global_cluster.main[0].id : null

  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [var.aurora_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_pg16.name

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = !var.deletion_protection
  final_snapshot_identifier       = var.deletion_protection ? "${local.cluster_id}-final-snapshot" : null
  copy_tags_to_snapshot           = true
  apply_immediately               = false

  # Enable IAM database authentication
  iam_database_authentication_enabled = true

  # Enable CloudWatch log exports
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Serverless v2 scaling (optional)
  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  lifecycle {
    ignore_changes = [master_password]
  }

  tags = merge(var.tags, {
    Name = local.cluster_id
  })
}

###############################################################################
# Aurora Writer Instance
###############################################################################

resource "aws_rds_cluster_instance" "writer" {
  identifier              = "${local.cluster_id}-writer"
  cluster_identifier      = aws_rds_cluster.primary.id
  instance_class          = var.instance_class
  engine                  = aws_rds_cluster.primary.engine
  engine_version          = aws_rds_cluster.primary.engine_version
  db_parameter_group_name = aws_db_parameter_group.aurora_pg16_instance.name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name

  publicly_accessible       = false
  auto_minor_version_upgrade = true

  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_arn

  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-writer"
    Role = "writer"
  })
}

###############################################################################
# Aurora Reader Instances
###############################################################################

resource "aws_rds_cluster_instance" "readers" {
  count                   = var.reader_count
  identifier              = "${local.cluster_id}-reader-${count.index + 1}"
  cluster_identifier      = aws_rds_cluster.primary.id
  instance_class          = var.instance_class
  engine                  = aws_rds_cluster.primary.engine
  engine_version          = aws_rds_cluster.primary.engine_version
  db_parameter_group_name = aws_db_parameter_group.aurora_pg16_instance.name
  db_subnet_group_name    = aws_db_subnet_group.aurora.name

  publicly_accessible       = false
  auto_minor_version_upgrade = true

  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = var.kms_key_arn

  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-reader-${count.index + 1}"
    Role = "reader"
  })
}

###############################################################################
# Aurora Auto-Scaling for Read Replicas
###############################################################################

resource "aws_appautoscaling_target" "aurora_read_replicas" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_replicas
  min_capacity       = var.reader_count
  resource_id        = "cluster:${aws_rds_cluster.primary.id}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"
}

resource "aws_appautoscaling_policy" "aurora_cpu_scaling" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${local.cluster_id}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.aurora_read_replicas[0].resource_id
  scalable_dimension = aws_appautoscaling_target.aurora_read_replicas[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.aurora_read_replicas[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
  }
}

###############################################################################
# CloudWatch Alarms for Aurora
###############################################################################

resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "${local.cluster_id}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora CPU utilization > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  ok_actions    = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_connections_high" {
  alarm_name          = "${local.cluster_id}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 500
  alarm_description   = "Aurora database connections > 500"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "aurora_freeable_memory_low" {
  alarm_name          = "${local.cluster_id}-freeable-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 1073741824  # 1 GB in bytes
  alarm_description   = "Aurora freeable memory < 1GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = var.tags
}

###############################################################################
# Secrets Manager - DB Credentials (managed here for rotation)
###############################################################################

resource "aws_secretsmanager_secret" "aurora_creds" {
  name                    = "${local.cluster_id}/credentials"
  description             = "Aurora PostgreSQL master credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "aurora_creds" {
  secret_id = aws_secretsmanager_secret.aurora_creds.id
  secret_string = jsonencode({
    username             = aws_rds_cluster.primary.master_username
    password             = var.master_password
    engine               = "postgres"
    host                 = aws_rds_cluster.primary.endpoint
    port                 = 5432
    dbname               = var.database_name
    dbClusterIdentifier  = aws_rds_cluster.primary.id
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "aurora_creds" {
  secret_id           = aws_secretsmanager_secret.aurora_creds.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = 30
  }
}
