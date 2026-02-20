###############################################################################
# ElastiCache Redis 7 - Cluster Mode, Multi-AZ, Encrypted, Auto-scaling
###############################################################################

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  cluster_id    = "${local.name_prefix}-redis"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# ElastiCache Subnet Group
###############################################################################

resource "aws_elasticache_subnet_group" "redis" {
  name        = "${local.cluster_id}-subnet-group"
  description = "Subnet group for Redis cluster"
  subnet_ids  = var.data_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-subnet-group"
  })
}

###############################################################################
# Redis Parameter Group
###############################################################################

resource "aws_elasticache_parameter_group" "redis7" {
  family      = "redis7"
  name        = "${local.cluster_id}-params"
  description = "Redis 7 parameter group for CIAM platform"

  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"  # Expired events for session tracking
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "lazyfree-lazy-eviction"
    value = "yes"
  }

  parameter {
    name  = "lazyfree-lazy-expire"
    value = "yes"
  }

  parameter {
    name  = "activerehashing"
    value = "yes"
  }

  parameter {
    name  = "activedefrag"
    value = "yes"
  }

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"  # 10ms
  }

  parameter {
    name  = "slowlog-max-len"
    value = "256"
  }

  tags = var.tags
}

###############################################################################
# Auth Token (generated and stored in Secrets Manager)
###############################################################################

resource "random_password" "redis_auth_token" {
  length           = 64
  special          = false  # Redis auth tokens cannot contain special chars
  override_special = ""
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${local.cluster_id}/auth-token"
  description             = "Redis cluster authentication token"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-auth-token"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token   = random_password.redis_auth_token.result
    host         = aws_elasticache_replication_group.redis.configuration_endpoint_address
    port         = 6379
    cluster_mode = true
  })
}

###############################################################################
# ElastiCache Redis Replication Group (Cluster Mode)
###############################################################################

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = local.cluster_id
  description          = "Redis 7 cluster for CIAM - session management, rate limiting, caching"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis7.name

  # Cluster mode configuration
  num_node_groups         = var.num_shards
  replicas_per_node_group = var.replicas_per_shard

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  # Multi-AZ
  multi_az_enabled           = true
  automatic_failover_enabled = true

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = var.kms_key_arn

  # Backups
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:30-sun:05:30"

  # Updates
  auto_minor_version_upgrade = true
  apply_immediately          = false

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_logs.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_logs.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(var.tags, {
    Name = local.cluster_id
  })
}

###############################################################################
# CloudWatch Log Groups for Redis
###############################################################################

resource "aws_cloudwatch_log_group" "redis_slow_logs" {
  name              = "/aws/elasticache/redis/${local.cluster_id}/slow-log"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-slow-logs"
  })
}

resource "aws_cloudwatch_log_group" "redis_engine_logs" {
  name              = "/aws/elasticache/redis/${local.cluster_id}/engine-log"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${local.cluster_id}-engine-logs"
  })
}

###############################################################################
# Application Auto Scaling for Redis
###############################################################################

resource "aws_appautoscaling_target" "redis_shards" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_shards
  min_capacity       = var.num_shards
  resource_id        = "replication-group/${aws_elasticache_replication_group.redis.id}"
  scalable_dimension = "elasticache:replication-group:NodeGroups"
  service_namespace  = "elasticache"
}

resource "aws_appautoscaling_policy" "redis_scale_out" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${local.cluster_id}-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.redis_shards[0].resource_id
  scalable_dimension = aws_appautoscaling_target.redis_shards[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.redis_shards[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 65.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ElastiCachePrimaryEngineCPUUtilization"
    }
  }
}

###############################################################################
# CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${local.cluster_id}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "EngineCPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Redis CPU > 75%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  alarm_name          = "${local.cluster_id}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis memory usage > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_connections_high" {
  alarm_name          = "${local.cluster_id}-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 10000
  alarm_description   = "Redis connections > 10,000"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions_high" {
  alarm_name          = "${local.cluster_id}-evictions-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Redis evictions > 100 per 5 minutes - consider scaling"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}
