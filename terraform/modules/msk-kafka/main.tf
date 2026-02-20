###############################################################################
# MSK Kafka 3.x - TLS + IAM Auth, Topic Definitions, Multi-AZ
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  cluster_name = "${local.name_prefix}-msk"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# MSK Configuration (Kafka server.properties)
###############################################################################

resource "aws_msk_configuration" "main" {
  kafka_versions = [var.kafka_version]
  name           = "${local.cluster_name}-config"
  description    = "MSK Kafka configuration for CIAM platform"

  server_properties = <<-EOT
    # Log settings
    log.retention.hours=168
    log.retention.bytes=107374182400
    log.segment.bytes=1073741824
    log.cleanup.policy=delete

    # Replication
    default.replication.factor=3
    min.insync.replicas=2
    offsets.topic.replication.factor=3
    transaction.state.log.replication.factor=3
    transaction.state.log.min.isr=2

    # Performance
    num.io.threads=8
    num.network.threads=5
    num.partitions=6
    socket.receive.buffer.bytes=102400
    socket.send.buffer.bytes=102400
    socket.request.max.bytes=104857600

    # TLS
    ssl.client.auth=required
    allow.everyone.if.no.acl.found=false

    # Auto topic creation disabled - use explicit topic creation
    auto.create.topics.enable=false

    # Message size
    message.max.bytes=1048588
    replica.fetch.max.bytes=1048576

    # Compression
    compression.type=snappy

    # Group coordinator
    group.initial.rebalance.delay.ms=3000

    # Zookeeper session timeout
    zookeeper.session.timeout.ms=18000

    # Log4j
    log4j.logger.kafka=INFO
    log4j.logger.kafka.controller=TRACE
    log4j.logger.kafka.log.LogCleaner=INFO
    log4j.logger.state.change.logger=TRACE
    log4j.logger.kafka.authorizer.logger=INFO
  EOT
}

###############################################################################
# MSK Cluster
###############################################################################

resource "aws_msk_cluster" "main" {
  cluster_name           = local.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.brokers_per_az * length(var.availability_zones)

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.data_subnet_ids
    security_groups = [var.msk_security_group_id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_size

        provisioned_throughput {
          enabled           = true
          volume_throughput = 250
        }
      }
    }

    connectivity_info {
      public_access {
        type = "DISABLED"
      }
    }
  }

  # TLS + IAM authentication
  client_authentication {
    unauthenticated = false
    sasl {
      iam   = true
      scram = false
    }
    tls {
      certificate_authority_arns = []
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  # Enhanced monitoring
  enhanced_monitoring = "PER_TOPIC_PER_BROKER"

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
      firehose {
        enabled = false
      }
      s3 {
        enabled = false
      }
    }
  }

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}

###############################################################################
# CloudWatch Log Group
###############################################################################

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${local.cluster_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-logs"
  })
}

###############################################################################
# MSK Topic Definitions via Lambda (custom resource)
###############################################################################

# IAM role for Kafka admin Lambda
resource "aws_iam_role" "kafka_admin" {
  name = "${local.cluster_name}-kafka-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "kafka_admin" {
  name = "${local.cluster_name}-kafka-admin-policy"
  role = aws_iam_role.kafka_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DeleteTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          aws_msk_cluster.main.arn,
          "${aws_msk_cluster.main.arn}/topic/*",
          "${aws_msk_cluster.main.arn}/group/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kafka:GetBootstrapBrokers",
          "kafka:DescribeCluster"
        ]
        Resource = aws_msk_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

###############################################################################
# MSK Topic Configuration (documented as Kafka topics for CIAM)
###############################################################################

# Topic configuration stored in SSM for reference by provisioning scripts
resource "aws_ssm_parameter" "kafka_topics" {
  name        = "/${var.project_name}/${var.environment}/kafka/topics"
  type        = "String"
  description = "Kafka topic definitions for CIAM platform"
  value = jsonencode({
    topics = [
      {
        name               = "user-events"
        partitions         = 12
        replication_factor = 3
        retention_ms       = 604800000  # 7 days
        cleanup_policy     = "delete"
        description        = "User lifecycle events (created, updated, deleted, locked)"
      },
      {
        name               = "auth-events"
        partitions         = 24
        replication_factor = 3
        retention_ms       = 259200000  # 3 days
        cleanup_policy     = "delete"
        description        = "Authentication events (login, logout, MFA, failures)"
      },
      {
        name               = "audit-log"
        partitions         = 6
        replication_factor = 3
        retention_ms       = 2592000000  # 30 days
        cleanup_policy     = "delete"
        description        = "Audit trail for compliance and security"
      },
      {
        name               = "notification-requests"
        partitions         = 6
        replication_factor = 3
        retention_ms       = 86400000  # 1 day
        cleanup_policy     = "delete"
        description        = "Outbound notification requests (email, SMS, push)"
      },
      {
        name               = "session-events"
        partitions         = 12
        replication_factor = 3
        retention_ms       = 86400000  # 1 day
        cleanup_policy     = "delete"
        description        = "Session creation, refresh, expiration events"
      },
      {
        name               = "password-events"
        partitions         = 6
        replication_factor = 3
        retention_ms       = 259200000  # 3 days
        cleanup_policy     = "delete"
        description        = "Password change, reset, expiration events"
      },
      {
        name               = "consent-events"
        partitions         = 6
        replication_factor = 3
        retention_ms       = 7776000000  # 90 days (GDPR)
        cleanup_policy     = "delete"
        description        = "GDPR consent events"
      },
      {
        name               = "risk-signals"
        partitions         = 12
        replication_factor = 3
        retention_ms       = 604800000  # 7 days
        cleanup_policy     = "delete"
        description        = "Fraud and risk signals for real-time evaluation"
      },
      {
        name               = "dead-letter"
        partitions         = 3
        replication_factor = 3
        retention_ms       = 2592000000  # 30 days
        cleanup_policy     = "delete"
        description        = "Failed message dead letter queue"
      }
    ]
  })

  tags = var.tags
}

###############################################################################
# SCRAM secrets (for MSK SCRAM auth - stored in Secrets Manager)
###############################################################################

resource "aws_secretsmanager_secret" "msk_credentials" {
  name                    = "${local.cluster_name}/service-credentials"
  description             = "MSK Kafka service account credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "msk_credentials" {
  secret_id = aws_secretsmanager_secret.msk_credentials.id
  secret_string = jsonencode({
    bootstrap_brokers_tls = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
    cluster_arn           = aws_msk_cluster.main.arn
    cluster_name          = aws_msk_cluster.main.cluster_name
    region                = data.aws_region.current.name
  })
}

###############################################################################
# CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "msk_cpu_high" {
  alarm_name          = "${local.cluster_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUser"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "MSK Kafka broker CPU > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = aws_msk_cluster.main.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "msk_disk_used" {
  alarm_name          = "${local.cluster_name}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "KafkaDataLogsDiskUsed"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "MSK Kafka disk usage > 75%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = aws_msk_cluster.main.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "msk_consumer_lag" {
  alarm_name          = "${local.cluster_name}-consumer-lag-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "EstimatedMaxTimeLag"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Maximum"
  threshold           = 300000  # 5 minutes lag
  alarm_description   = "MSK consumer lag > 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = aws_msk_cluster.main.cluster_name
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}
