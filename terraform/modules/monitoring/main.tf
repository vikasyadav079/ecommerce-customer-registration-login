###############################################################################
# Monitoring Module - CloudWatch Dashboards, Alarms, Synthetics Canaries
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# SNS Topics for Alerting
###############################################################################

resource "aws_sns_topic" "critical_alerts" {
  name              = "${local.name_prefix}-critical-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name     = "${local.name_prefix}-critical-alerts"
    Severity = "critical"
  })
}

resource "aws_sns_topic" "warning_alerts" {
  name              = "${local.name_prefix}-warning-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name     = "${local.name_prefix}-warning-alerts"
    Severity = "warning"
  })
}

resource "aws_sns_topic_subscription" "email_critical" {
  for_each  = toset(var.alarm_email_endpoints)
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "email_warning" {
  for_each  = toset(var.alarm_email_endpoints)
  topic_arn = aws_sns_topic.warning_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

###############################################################################
# CloudWatch Dashboards
###############################################################################

resource "aws_cloudwatch_dashboard" "ciam_overview" {
  dashboard_name = "${local.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # Title
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## CIAM Platform Overview - ${upper(var.environment)}"
        }
      },
      # Authentication Success Rate
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Auth Success Rate"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "AuthSuccess", "Environment", var.environment],
            ["CIAMPlatform", "AuthFailure", "Environment", var.environment]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      # Active Sessions
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Active Sessions"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "ActiveSessions", "Environment", var.environment]
          ]
          period = 60
          stat   = "Average"
        }
      },
      # API Latency P99
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "API Latency P99 (ms)"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99" }]
          ]
          period = 60
        }
      },
      # EKS Node Status
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "EKS Cluster CPU/Memory"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.eks_cluster_name, { stat = "Average", label = "CPU %" }],
            ["ContainerInsights", "node_memory_utilization", "ClusterName", var.eks_cluster_name, { stat = "Average", label = "Memory %" }]
          ]
          period = 60
        }
      },
      # Aurora Performance
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "Aurora DB Connections & CPU"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_id, { stat = "Average", label = "Connections" }],
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_id, { stat = "Average", label = "CPU %" }]
          ]
          period = 60
        }
      },
      # Redis Performance
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "Redis Cache Hit Rate & Memory"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ElastiCache", "CacheHitRate", "ReplicationGroupId", var.redis_cluster_id, { stat = "Average", label = "Hit Rate %" }],
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "ReplicationGroupId", var.redis_cluster_id, { stat = "Average", label = "Memory %" }]
          ]
          period = 60
        }
      },
      # WAF Blocked Requests
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "WAF - Allowed vs Blocked Requests"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_acl_name, "Region", data.aws_region.current.name, "Rule", "ALL"],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_acl_name, "Region", data.aws_region.current.name, "Rule", "ALL"]
          ]
          period = 300
          stat   = "Sum"
        }
      },
      # Error Rates
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "HTTP Error Rates (4xx/5xx)"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "4xx Errors" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", label = "5xx Errors" }]
          ]
          period = 60
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "ciam_security" {
  dashboard_name = "${local.name_prefix}-security"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## CIAM Security Dashboard - ${upper(var.environment)}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Failed Login Attempts"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "FailedLoginAttempts", "Environment", var.environment, { stat = "Sum" }]
          ]
          period = 300
          annotations = {
            horizontal = [{ label = "Alert threshold", value = 100 }]
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Account Lockouts"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "AccountLockouts", "Environment", var.environment, { stat = "Sum" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "MFA Challenges Issued vs Passed"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "MFAChallengesIssued", "Environment", var.environment, { stat = "Sum" }],
            ["CIAMPlatform", "MFAChallengesPassed", "Environment", var.environment, { stat = "Sum" }]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Rate-Limited Requests (Auth Endpoint)"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_acl_name, "Region", data.aws_region.current.name, "Rule", "RateLimitAuthEndpoint"]
          ]
          period = 60
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Token Issuance Rate"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["CIAMPlatform", "TokensIssued", "Environment", var.environment, "TokenType", "access_token", { stat = "Sum" }],
            ["CIAMPlatform", "TokensIssued", "Environment", var.environment, "TokenType", "refresh_token", { stat = "Sum" }]
          ]
          period = 300
        }
      }
    ]
  })
}

###############################################################################
# Critical CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "high_5xx_errors" {
  alarm_name          = "${local.name_prefix}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 10
  alarm_description   = "5xx error rate > 10 per minute - service degradation"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "rate"
    expression  = "errors/requests*100"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "requests"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "high_auth_failures" {
  alarm_name          = "${local.name_prefix}-high-auth-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FailedLoginAttempts"
  namespace           = "CIAMPlatform"
  period              = 300
  statistic           = "Sum"
  threshold           = 500
  alarm_description   = "High auth failure rate - possible credential stuffing attack"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Environment = var.environment
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency_p99" {
  alarm_name          = "${local.name_prefix}-api-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 2
  alarm_description   = "API P99 latency > 2 seconds"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "eks_pods_pending" {
  alarm_name          = "${local.name_prefix}-eks-pods-pending"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "pod_number_of_running_containers"
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 pods pending scheduling"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.eks_cluster_name
    phase       = "Pending"
  }

  alarm_actions = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

###############################################################################
# CloudWatch Synthetics Canaries
###############################################################################

resource "aws_iam_role" "synthetics" {
  name = "${local.name_prefix}-synthetics-role"

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

resource "aws_iam_role_policy" "synthetics" {
  name = "${local.name_prefix}-synthetics-policy"
  role = aws_iam_role.synthetics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.canary_artifacts.arn,
          "${aws_s3_bucket.canary_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "canary_artifacts" {
  bucket = "${local.name_prefix}-canary-artifacts"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-canary-artifacts"
  })
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  bucket                  = aws_s3_bucket.canary_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Health Check Canary
resource "aws_synthetics_canary" "api_health_check" {
  name                 = "${local.name_prefix}-api-health"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.bucket}/api-health/"
  execution_role_arn   = aws_iam_role.synthetics.arn
  handler              = "apiCanary.handler"
  zip_file             = data.archive_file.canary_health_check.output_path
  runtime_version      = "syn-nodejs-puppeteer-7.0"
  start_canary         = true

  schedule {
    expression          = "rate(1 minute)"
    duration_in_seconds = 0
  }

  run_config {
    timeout_in_seconds    = 60
    memory_in_mb          = 960
    active_tracing        = true
    environment_variables = {
      BASE_URL = "https://${var.domain_name}"
    }
  }

  success_retention_period = 2   # days
  failure_retention_period = 14  # days

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-api-health-canary"
  })
}

data "archive_file" "canary_health_check" {
  type        = "zip"
  output_path = "/tmp/canary-health-check.zip"

  source {
    filename = "apiCanary.js"
    content  = <<-EOT
      const synthetics = require('Synthetics');
      const log = require('SyntheticsLogger');
      const https = require('https');

      const BASE_URL = process.env.BASE_URL || 'https://api.example.com';

      const checkEndpoint = async (path, expectedStatus = 200) => {
        return new Promise((resolve, reject) => {
          const url = `${BASE_URL}${path}`;
          https.get(url, (res) => {
            if (res.statusCode === expectedStatus) {
              resolve({ path, status: res.statusCode, success: true });
            } else {
              reject(new Error(`${path} returned ${res.statusCode}, expected ${expectedStatus}`));
            }
          }).on('error', reject);
        });
      };

      const apiCanary = async () => {
        const checks = [
          { path: '/health', expected: 200 },
          { path: '/api/v1/health', expected: 200 },
          { path: '/.well-known/openid-configuration', expected: 200 },
          { path: '/.well-known/jwks.json', expected: 200 },
        ];

        for (const check of checks) {
          try {
            await checkEndpoint(check.path, check.expected);
            log.info(`PASS: ${check.path}`);
            synthetics.addExecutionError(`${check.path} check passed`, false);
          } catch (error) {
            log.error(`FAIL: ${check.path} - ${error.message}`);
            throw error;
          }
        }
      };

      exports.handler = async () => {
        return await apiCanary();
      };
    EOT
  }
}

# Login Flow Canary
resource "aws_synthetics_canary" "login_flow" {
  name                 = "${local.name_prefix}-login-flow"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.bucket}/login-flow/"
  execution_role_arn   = aws_iam_role.synthetics.arn
  handler              = "loginCanary.handler"
  zip_file             = data.archive_file.canary_login_flow.output_path
  runtime_version      = "syn-nodejs-puppeteer-7.0"
  start_canary         = true

  schedule {
    expression          = "rate(5 minutes)"
    duration_in_seconds = 0
  }

  run_config {
    timeout_in_seconds = 120
    memory_in_mb       = 960
    active_tracing     = true
    environment_variables = {
      BASE_URL      = "https://${var.domain_name}"
      TEST_USERNAME = var.canary_test_username
      TEST_PASSWORD = var.canary_test_password
    }
  }

  success_retention_period = 2
  failure_retention_period = 14

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-login-flow-canary"
  })
}

data "archive_file" "canary_login_flow" {
  type        = "zip"
  output_path = "/tmp/canary-login-flow.zip"

  source {
    filename = "loginCanary.js"
    content  = <<-EOT
      const synthetics = require('Synthetics');
      const log = require('SyntheticsLogger');

      const BASE_URL = process.env.BASE_URL;
      const TEST_USERNAME = process.env.TEST_USERNAME;
      const TEST_PASSWORD = process.env.TEST_PASSWORD;

      const loginCanary = async () => {
        const page = await synthetics.getPage();

        await page.goto(`${BASE_URL}/login`, { waitUntil: 'networkidle0' });
        await page.waitForSelector('#username', { timeout: 10000 });

        await page.type('#username', TEST_USERNAME);
        await page.type('#password', TEST_PASSWORD);
        await page.click('#login-button');

        await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 30000 });

        const url = page.url();
        if (!url.includes('/dashboard') && !url.includes('/home')) {
          throw new Error(`Login failed - redirected to: ${url}`);
        }

        log.info('Login flow canary passed successfully');
      };

      exports.handler = async () => {
        return await loginCanary();
      };
    EOT
  }
}

###############################################################################
# Canary Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "canary_api_health" {
  alarm_name          = "${local.name_prefix}-canary-api-health-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "API health canary success rate < 90%"
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = aws_synthetics_canary.api_health_check.name
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "canary_login_flow" {
  alarm_name          = "${local.name_prefix}-canary-login-flow-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 600
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Login flow canary success rate < 80%"
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = aws_synthetics_canary.login_flow.name
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  tags          = var.tags
}

###############################################################################
# Container Insights (EKS)
###############################################################################

resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.eks_cluster_name}/performance"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}
