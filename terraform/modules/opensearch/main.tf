###############################################################################
# OpenSearch 2.x Domain - VPC Access, Index Lifecycle Policies
###############################################################################

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  domain_name   = "${local.name_prefix}-os"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# Service-Linked Role for OpenSearch VPC Access
###############################################################################

resource "aws_iam_service_linked_role" "opensearch" {
  count            = var.create_service_linked_role ? 1 : 0
  aws_service_name = "es.amazonaws.com"
  description      = "Service-linked role for OpenSearch VPC access"
}

###############################################################################
# OpenSearch Domain
###############################################################################

resource "aws_opensearch_domain" "main" {
  domain_name    = local.domain_name
  engine_version = "OpenSearch_${var.opensearch_version}"

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    dedicated_master_enabled = var.instance_count >= 3
    dedicated_master_type    = var.instance_count >= 3 ? var.dedicated_master_type : null
    dedicated_master_count   = var.instance_count >= 3 ? 3 : null
    zone_awareness_enabled   = var.instance_count > 1

    dynamic "zone_awareness_config" {
      for_each = var.instance_count > 1 ? [1] : []
      content {
        availability_zone_count = min(var.instance_count, 3)
      }
    }

    warm_enabled = var.enable_ultrawarm
    warm_type    = var.enable_ultrawarm ? "ultrawarm1.medium.search" : null
    warm_count   = var.enable_ultrawarm ? 2 : null
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.volume_size
    iops        = 3000
    throughput  = 125
  }

  vpc_options {
    subnet_ids         = slice(var.data_subnet_ids, 0, min(var.instance_count, 3))
    security_group_ids = [var.opensearch_security_group_id]
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https                   = true
    tls_security_policy             = "Policy-Min-TLS-1-2-2019-07"
    custom_endpoint_enabled         = false
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = false

    master_user_options {
      master_user_arn = var.master_user_arn
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_error.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_audit.arn
    log_type                 = "AUDIT_LOGS"
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "override_main_response_version"        = "false"
    "indices.query.bool.max_clause_count"   = "1024"
  }

  auto_tune_options {
    desired_state       = "ENABLED"
    rollback_on_disable = "NO_ROLLBACK"
  }

  software_update_options {
    auto_software_update_enabled = false
  }

  tags = merge(var.tags, {
    Name = local.domain_name
  })

  depends_on = [aws_iam_service_linked_role.opensearch]
}

###############################################################################
# CloudWatch Log Groups
###############################################################################

resource "aws_cloudwatch_log_group" "opensearch_index_slow" {
  name              = "/aws/opensearch/${local.domain_name}/index-slow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "opensearch_search_slow" {
  name              = "/aws/opensearch/${local.domain_name}/search-slow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "opensearch_error" {
  name              = "/aws/opensearch/${local.domain_name}/application-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "opensearch_audit" {
  name              = "/aws/opensearch/${local.domain_name}/audit-logs"
  retention_in_days = 365  # Compliance requirement - 1 year
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

###############################################################################
# CloudWatch Log Resource Policy (allows OpenSearch to write logs)
###############################################################################

resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "${local.domain_name}-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:PutLogEventsBatch",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:*"
      }
    ]
  })
}

###############################################################################
# OpenSearch Access Policy
###############################################################################

resource "aws_opensearch_domain_policy" "main" {
  domain_name = aws_opensearch_domain.main.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            var.master_user_arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
        Action   = "es:*"
        Resource = "${aws_opensearch_domain.main.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.service_role_arns
        }
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead",
          "es:DescribeDomain"
        ]
        Resource = "${aws_opensearch_domain.main.arn}/*"
      }
    ]
  })
}

###############################################################################
# Index Templates (stored in SSM for initialization scripts)
###############################################################################

resource "aws_ssm_parameter" "opensearch_index_config" {
  name        = "/${var.project_name}/${var.environment}/opensearch/index-config"
  type        = "String"
  description = "OpenSearch index templates and ILM policies"
  value = jsonencode({
    index_templates = [
      {
        name = "audit-logs-template"
        pattern = "audit-logs-*"
        settings = {
          number_of_shards   = 3
          number_of_replicas = 1
          refresh_interval   = "30s"
        }
        ilm_policy = "audit-logs-ilm"
      },
      {
        name = "user-events-template"
        pattern = "user-events-*"
        settings = {
          number_of_shards   = 3
          number_of_replicas = 1
          refresh_interval   = "10s"
        }
        ilm_policy = "user-events-ilm"
      },
      {
        name = "auth-events-template"
        pattern = "auth-events-*"
        settings = {
          number_of_shards   = 6
          number_of_replicas = 1
          refresh_interval   = "5s"
        }
        ilm_policy = "auth-events-ilm"
      }
    ]
    ilm_policies = [
      {
        name = "audit-logs-ilm"
        phases = {
          hot = {
            rollover_max_age  = "7d"
            rollover_max_size = "50gb"
            priority          = 100
          }
          warm = {
            min_age          = "7d"
            move_to_ultrawarm = true
          }
          cold = {
            min_age = "30d"
          }
          delete = {
            min_age = "365d"
          }
        }
      },
      {
        name = "auth-events-ilm"
        phases = {
          hot = {
            rollover_max_age  = "1d"
            rollover_max_size = "20gb"
            priority          = 100
          }
          warm = {
            min_age = "3d"
          }
          delete = {
            min_age = "90d"
          }
        }
      },
      {
        name = "user-events-ilm"
        phases = {
          hot = {
            rollover_max_age  = "3d"
            rollover_max_size = "30gb"
            priority          = 100
          }
          warm = {
            min_age = "7d"
          }
          delete = {
            min_age = "180d"
          }
        }
      }
    ]
  })

  tags = var.tags
}

###############################################################################
# CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_red" {
  alarm_name          = "${local.domain_name}-cluster-red"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "OpenSearch cluster status is RED"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_yellow" {
  alarm_name          = "${local.domain_name}-cluster-yellow"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "OpenSearch cluster status is YELLOW"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_free_storage_low" {
  alarm_name          = "${local.domain_name}-free-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Minimum"
  threshold           = 20480  # 20GB in MB
  alarm_description   = "OpenSearch free storage < 20GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cpu_high" {
  alarm_name          = "${local.domain_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "OpenSearch CPU > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.main.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}
