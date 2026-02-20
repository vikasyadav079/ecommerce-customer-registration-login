###############################################################################
# WAF v2 + Shield Advanced - OWASP CRS Rules, Rate Limiting
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  waf_name    = "${local.name_prefix}-waf"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# WAF v2 Web ACL
###############################################################################

resource "aws_wafv2_web_acl" "main" {
  name        = local.waf_name
  description = "WAF ACL for CIAM platform - OWASP rules + rate limiting"
  scope       = var.scope  # REGIONAL for ALB/API GW, CLOUDFRONT for CF distributions

  default_action {
    allow {}
  }

  ###############################################################################
  # Rule 1: AWS Managed - IP Reputation List (Block known bad IPs)
  ###############################################################################
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 2: AWS Managed - Common Rule Set (OWASP CRS)
  ###############################################################################
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Override rules that may cause false positives
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }

        rule_action_override {
          name = "GenericRFI_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 3: AWS Managed - Known Bad Inputs (Log4Shell, SSRF, etc.)
  ###############################################################################
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 4: AWS Managed - SQL Injection Protection
  ###############################################################################
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-sqli"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 5: AWS Managed - Linux OS Rules
  ###############################################################################
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 50

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-linux-rules"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 6: Rate Limit - Auth endpoints (100 req / 5 min per IP)
  ###############################################################################
  rule {
    name     = "RateLimitAuthEndpoint"
    priority = 60

    action {
      block {
        custom_response {
          response_code = 429
          response_header {
            name  = "Retry-After"
            value = "300"
          }
          custom_response_body_key = "rate_limit_response"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
        evaluation_window_sec = 300  # 5 minutes

        scope_down_statement {
          byte_match_statement {
            search_string         = "/api/v1/auth/"
            field_to_match {
              uri_path {}
            }
            text_transformations {
              priority = 1
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-rate-limit-auth"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 7: Rate Limit - Password Reset endpoint (10 req / 5 min per IP)
  ###############################################################################
  rule {
    name     = "RateLimitPasswordReset"
    priority = 70

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_response"
        }
      }
    }

    statement {
      rate_based_statement {
        limit                 = 10
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300

        scope_down_statement {
          byte_match_statement {
            search_string = "/api/v1/auth/password-reset"
            field_to_match {
              uri_path {}
            }
            text_transformations {
              priority = 1
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-rate-limit-password-reset"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 8: Rate Limit - Global API (1000 req / 5 min per IP)
  ###############################################################################
  rule {
    name     = "RateLimitGlobalAPI"
    priority = 80

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_response"
        }
      }
    }

    statement {
      rate_based_statement {
        limit                 = 1000
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-rate-limit-global"
      sampled_requests_enabled   = true
    }
  }

  ###############################################################################
  # Rule 9: Geo-blocking (optional)
  ###############################################################################
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 90

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.waf_name}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  ###############################################################################
  # Rule 10: IP Allowlist (for admin/internal access)
  ###############################################################################
  dynamic "rule" {
    for_each = length(var.admin_allowed_ips) > 0 ? [1] : []
    content {
      name     = "AdminIPAllowList"
      priority = 5

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.admin_allowlist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.waf_name}-admin-allowlist"
        sampled_requests_enabled   = false
      }
    }
  }

  custom_response_bodies {
    key          = "rate_limit_response"
    content_type = "APPLICATION_JSON"
    content      = jsonencode({
      error   = "Too Many Requests"
      message = "Rate limit exceeded. Please try again later."
      code    = "RATE_LIMIT_EXCEEDED"
    })
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.waf_name
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = local.waf_name
  })
}

###############################################################################
# IP Set for Admin Allowlist
###############################################################################

resource "aws_wafv2_ip_set" "admin_allowlist" {
  count              = length(var.admin_allowed_ips) > 0 ? 1 : 0
  name               = "${local.waf_name}-admin-allowlist"
  description        = "Allowed IP addresses for admin access"
  scope              = var.scope
  ip_address_version = "IPV4"
  addresses          = var.admin_allowed_ips

  tags = merge(var.tags, {
    Name = "${local.waf_name}-admin-allowlist"
  })
}

###############################################################################
# WAF Logging Configuration
###############################################################################

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      requirement = "MEETS_ANY"
    }

    filter {
      behavior = "DROP"
      condition {
        action_condition {
          action = "ALLOW"
        }
      }
      requirement = "MEETS_ALL"
    }
  }

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "/aws/wafv2/${local.waf_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${local.waf_name}-logs"
  })
}

###############################################################################
# Shield Advanced (optional - significant cost ~$3000/month)
###############################################################################

resource "aws_shield_protection" "alb" {
  count        = var.enable_shield_advanced ? 1 : 0
  name         = "${local.name_prefix}-alb-shield"
  resource_arn = var.alb_arn
}

resource "aws_shield_protection" "cloudfront" {
  count        = var.enable_shield_advanced && var.cloudfront_arn != "" ? 1 : 0
  name         = "${local.name_prefix}-cloudfront-shield"
  resource_arn = var.cloudfront_arn

  provider = aws.us_east_1
}

resource "aws_shield_protection_group" "all" {
  count               = var.enable_shield_advanced ? 1 : 0
  protection_group_id = "${local.name_prefix}-protection-group"
  aggregation         = "MAX"
  pattern             = "ALL"

  tags = var.tags
}

###############################################################################
# WAF CloudWatch Alarms
###############################################################################

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${local.waf_name}-blocked-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "WAF blocked more than 1000 requests in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = data.aws_region.current.name
    Rule   = "ALL"
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limited_requests" {
  alarm_name          = "${local.waf_name}-rate-limited-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 500
  alarm_description   = "WAF rate limiting triggering heavily - possible brute force attack"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = data.aws_region.current.name
    Rule   = "RateLimitAuthEndpoint"
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}
