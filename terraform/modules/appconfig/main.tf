###############################################################################
# AWS AppConfig - Application, Environments, Feature Flag Profiles
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# AppConfig Application
###############################################################################

resource "aws_appconfig_application" "ciam" {
  name        = "${local.name_prefix}-ciam"
  description = "CIAM platform feature flags and configuration"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-appconfig"
  })
}

###############################################################################
# AppConfig Environments
###############################################################################

resource "aws_appconfig_environment" "main" {
  name           = var.environment
  description    = "CIAM ${var.environment} environment configuration"
  application_id = aws_appconfig_application.ciam.id

  dynamic "monitor" {
    for_each = var.alarm_arns
    content {
      alarm_arn      = monitor.value
      alarm_role_arn = aws_iam_role.appconfig_monitor.arn
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-appconfig-env"
  })
}

###############################################################################
# IAM Role for AppConfig CloudWatch Monitoring
###############################################################################

resource "aws_iam_role" "appconfig_monitor" {
  name = "${local.name_prefix}-appconfig-monitor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appconfig.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appconfig_monitor" {
  name = "${local.name_prefix}-appconfig-monitor-policy"
  role = aws_iam_role.appconfig_monitor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:DescribeAlarms"]
        Resource = "*"
      }
    ]
  })
}

###############################################################################
# AppConfig Deployment Strategy - Linear rollout
###############################################################################

resource "aws_appconfig_deployment_strategy" "linear_10_percent" {
  name                           = "${local.name_prefix}-linear-10pct"
  description                    = "10% incremental rollout over 50 minutes"
  deployment_duration_in_minutes = 50
  final_bake_time_in_minutes     = 10
  growth_factor                  = 10
  growth_type                    = "LINEAR"
  replicate_to                   = "SSM_DOCUMENT"

  tags = var.tags
}

resource "aws_appconfig_deployment_strategy" "all_at_once" {
  name                           = "${local.name_prefix}-all-at-once"
  description                    = "Instant deployment (dev/testing only)"
  deployment_duration_in_minutes = 0
  final_bake_time_in_minutes     = 0
  growth_factor                  = 100
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"

  tags = var.tags
}

resource "aws_appconfig_deployment_strategy" "canary_10_percent" {
  name                           = "${local.name_prefix}-canary-10pct"
  description                    = "Canary deployment at 10% for 30 minutes"
  deployment_duration_in_minutes = 30
  final_bake_time_in_minutes     = 30
  growth_factor                  = 10
  growth_type                    = "EXPONENTIAL"
  replicate_to                   = "SSM_DOCUMENT"

  tags = var.tags
}

###############################################################################
# Feature Flags Configuration Profile
###############################################################################

resource "aws_appconfig_configuration_profile" "feature_flags" {
  application_id = aws_appconfig_application.ciam.id
  name           = "${local.name_prefix}-feature-flags"
  description    = "Feature flags for CIAM platform"
  location_uri   = "hosted"
  type           = "AWS.AppConfig.FeatureFlags"

  validator {
    type = "JSON_SCHEMA"
    content = jsonencode({
      "$schema" = "http://json-schema.org/draft-07/schema"
      type      = "object"
      properties = {
        "mfa_enabled" = {
          type = "object"
          properties = {
            enabled = { type = "boolean" }
          }
        }
        "passwordless_login" = {
          type = "object"
          properties = {
            enabled = { type = "boolean" }
          }
        }
        "social_login" = {
          type = "object"
          properties = {
            enabled = { type = "boolean" }
            providers = {
              type  = "array"
              items = { type = "string" }
            }
          }
        }
      }
    })
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-feature-flags"
  })
}

resource "aws_appconfig_hosted_configuration_version" "feature_flags" {
  application_id           = aws_appconfig_application.ciam.id
  configuration_profile_id = aws_appconfig_configuration_profile.feature_flags.configuration_profile_id
  description              = "Initial feature flag configuration"
  content_type             = "application/json"

  content = jsonencode({
    version = "1"
    flags = {
      mfa_enabled = {
        name        = "MFA Enabled"
        description = "Enable multi-factor authentication globally"
        _deprecation = {}
        attributes = {
          mfa_methods = {
            type    = "string"
            default = "totp,sms,email"
          }
        }
      }
      passwordless_login = {
        name        = "Passwordless Login"
        description = "Enable passwordless authentication (magic links, passkeys)"
        _deprecation = {}
        attributes = {
          methods = {
            type    = "string"
            default = "magic_link,passkey"
          }
        }
      }
      social_login = {
        name        = "Social Login"
        description = "Enable social identity provider login"
        _deprecation = {}
        attributes = {
          providers = {
            type    = "string"
            default = "google,apple,facebook"
          }
        }
      }
      advanced_fraud_detection = {
        name        = "Advanced Fraud Detection"
        description = "Enable ML-based fraud detection for authentication"
        _deprecation = {}
      }
      session_binding = {
        name        = "Session Device Binding"
        description = "Bind sessions to device fingerprint"
        _deprecation = {}
        attributes = {
          strict_mode = {
            type    = "boolean"
            default = false
          }
        }
      }
      progressive_profiling = {
        name        = "Progressive Profiling"
        description = "Collect user profile data incrementally"
        _deprecation = {}
        attributes = {
          max_prompts = {
            type    = "number"
            default = 3
          }
        }
      }
      consent_management = {
        name        = "Granular Consent Management"
        description = "Enable GDPR granular consent collection and management"
        _deprecation = {}
      }
      account_linking = {
        name        = "Account Linking"
        description = "Allow users to link multiple identity providers"
        _deprecation = {}
        attributes = {
          max_linked_accounts = {
            type    = "number"
            default = 5
          }
        }
      }
    }
    values = {
      mfa_enabled              = { enabled = var.feature_mfa_enabled }
      passwordless_login       = { enabled = var.feature_passwordless_enabled }
      social_login             = { enabled = var.feature_social_login_enabled }
      advanced_fraud_detection = { enabled = var.feature_fraud_detection_enabled }
      session_binding          = { enabled = var.feature_session_binding_enabled }
      progressive_profiling    = { enabled = var.feature_progressive_profiling_enabled }
      consent_management       = { enabled = true }
      account_linking          = { enabled = var.feature_account_linking_enabled }
    }
  })
}

###############################################################################
# Service Configuration Profile (non-feature-flag settings)
###############################################################################

resource "aws_appconfig_configuration_profile" "service_config" {
  application_id = aws_appconfig_application.ciam.id
  name           = "${local.name_prefix}-service-config"
  description    = "Service runtime configuration parameters"
  location_uri   = "hosted"
  type           = "AWS.Freeform"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-service-config"
  })
}

resource "aws_appconfig_hosted_configuration_version" "service_config" {
  application_id           = aws_appconfig_application.ciam.id
  configuration_profile_id = aws_appconfig_configuration_profile.service_config.configuration_profile_id
  description              = "Service runtime configuration"
  content_type             = "application/json"

  content = jsonencode({
    auth = {
      access_token_ttl_seconds   = 900     # 15 minutes
      refresh_token_ttl_seconds  = 2592000 # 30 days
      id_token_ttl_seconds       = 3600    # 1 hour
      session_ttl_seconds        = 86400   # 24 hours
      max_failed_login_attempts  = 5
      account_lockout_duration_s = 900  # 15 minutes lockout
    }
    password = {
      min_length               = 12
      require_uppercase        = true
      require_lowercase        = true
      require_digits           = true
      require_special          = true
      history_count            = 12
      max_age_days             = 180
      bcrypt_rounds            = 12
    }
    rate_limits = {
      login_per_ip_per_minute         = 10
      password_reset_per_ip_per_hour  = 5
      token_refresh_per_user_per_hour = 20
      api_global_per_ip_per_minute    = 200
    }
    notifications = {
      email_provider        = "ses"
      sms_provider          = "twilio"
      push_provider         = "firebase"
      batch_size            = 100
      retry_max_attempts    = 3
      retry_backoff_seconds = 30
    }
    cors = {
      allowed_origins = var.cors_allowed_origins
      allowed_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      allowed_headers = ["Content-Type", "Authorization", "X-Request-ID"]
      max_age_seconds = 86400
    }
  })
}

###############################################################################
# AppConfig Deployment (initial)
###############################################################################

resource "aws_appconfig_deployment" "feature_flags_initial" {
  application_id           = aws_appconfig_application.ciam.id
  configuration_profile_id = aws_appconfig_configuration_profile.feature_flags.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.feature_flags.version_number
  deployment_strategy_id   = var.environment == "prod-us" || var.environment == "prod-eu" ? aws_appconfig_deployment_strategy.linear_10_percent.id : aws_appconfig_deployment_strategy.all_at_once.id
  environment_id           = aws_appconfig_environment.main.environment_id
  description              = "Initial feature flag deployment"

  tags = var.tags
}
