###############################################################################
# Secrets Manager - DB Creds, Redis Auth, JWT Keys, with Auto-Rotation
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# JWT Signing Keys (RSA Key Pairs)
###############################################################################

resource "aws_secretsmanager_secret" "jwt_private_key" {
  name                    = "${local.name_prefix}/jwt/private-key"
  description             = "RSA private key for JWT signing (active key)"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  replica {
    region     = var.replica_region
    kms_key_id = var.replica_kms_key_arn
  }

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-jwt-private-key"
    SecretType = "jwt-signing"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_private_key" {
  secret_id = aws_secretsmanager_secret.jwt_private_key.id
  secret_string = jsonencode({
    kid         = "key-${formatdate("YYYYMM", timestamp())}"
    private_key = var.jwt_private_key_pem
    public_key  = var.jwt_public_key_pem
    algorithm   = "RS256"
    created_at  = timestamp()
    expires_at  = timeadd(timestamp(), "8760h")  # 1 year
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "jwt_previous_key" {
  name                    = "${local.name_prefix}/jwt/previous-key"
  description             = "RSA private key for JWT verification (previous key, for token migration)"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-jwt-previous-key"
    SecretType = "jwt-verification"
  })
}

###############################################################################
# Database Credentials
###############################################################################

resource "aws_secretsmanager_secret" "db_ciam_service" {
  name                    = "${local.name_prefix}/db/ciam-service"
  description             = "Database credentials for CIAM main service account"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-db-ciam-service"
    SecretType = "database-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_ciam_service" {
  secret_id = aws_secretsmanager_secret.db_ciam_service.id
  secret_string = jsonencode({
    username = "ciam_service"
    password = var.db_ciam_service_password
    host     = var.db_host
    port     = 5432
    dbname   = var.db_name
    engine   = "postgres"
    ssl      = "require"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_rotation" "db_ciam_service" {
  count               = var.rotation_lambda_arn != "" ? 1 : 0
  secret_id           = aws_secretsmanager_secret.db_ciam_service.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotate_immediately  = false

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "db_readonly" {
  name                    = "${local.name_prefix}/db/readonly"
  description             = "Database credentials for read-only service account"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-db-readonly"
    SecretType = "database-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_readonly" {
  secret_id = aws_secretsmanager_secret.db_readonly.id
  secret_string = jsonencode({
    username     = "ciam_readonly"
    password     = var.db_readonly_password
    host         = var.db_reader_host
    port         = 5432
    dbname       = var.db_name
    engine       = "postgres"
    ssl          = "require"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# Redis Authentication Token
###############################################################################

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${local.name_prefix}/redis/auth-token"
  description             = "Redis cluster authentication token"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-redis-auth"
    SecretType = "cache-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token         = var.redis_auth_token
    configuration_endpoint = var.redis_configuration_endpoint
    port               = 6379
    ssl                = true
    cluster_mode       = true
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# OAuth2 Client Credentials
###############################################################################

resource "aws_secretsmanager_secret" "oauth2_client_secrets" {
  name                    = "${local.name_prefix}/oauth2/client-secrets"
  description             = "OAuth2 client credentials for system integrations"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-oauth2-clients"
    SecretType = "oauth2-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "oauth2_client_secrets" {
  secret_id = aws_secretsmanager_secret.oauth2_client_secrets.id
  secret_string = jsonencode({
    admin_portal = {
      client_id     = "admin-portal"
      client_secret = var.oauth2_admin_client_secret
      scopes        = ["admin:read", "admin:write", "user:manage"]
    }
    mobile_app = {
      client_id     = "mobile-app"
      client_secret = var.oauth2_mobile_client_secret
      scopes        = ["openid", "profile", "email", "offline_access"]
    }
    web_app = {
      client_id     = "web-app"
      client_secret = var.oauth2_web_client_secret
      scopes        = ["openid", "profile", "email"]
    }
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# SMTP / Email Service Credentials
###############################################################################

resource "aws_secretsmanager_secret" "smtp_credentials" {
  name                    = "${local.name_prefix}/email/smtp-credentials"
  description             = "SMTP server credentials for notification service"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-smtp-credentials"
    SecretType = "email-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "smtp_credentials" {
  secret_id = aws_secretsmanager_secret.smtp_credentials.id
  secret_string = jsonencode({
    host     = var.smtp_host
    port     = var.smtp_port
    username = var.smtp_username
    password = var.smtp_password
    from     = var.smtp_from_address
    tls      = true
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# SMS / Twilio Credentials
###############################################################################

resource "aws_secretsmanager_secret" "twilio_credentials" {
  name                    = "${local.name_prefix}/sms/twilio-credentials"
  description             = "Twilio credentials for SMS notifications and MFA"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-twilio-credentials"
    SecretType = "sms-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "twilio_credentials" {
  secret_id = aws_secretsmanager_secret.twilio_credentials.id
  secret_string = jsonencode({
    account_sid  = var.twilio_account_sid
    auth_token   = var.twilio_auth_token
    from_number  = var.twilio_from_number
    service_sid  = var.twilio_verify_service_sid
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# Encryption Keys - Application-Level
###############################################################################

resource "random_bytes" "app_encryption_key" {
  length = 32
}

resource "aws_secretsmanager_secret" "app_encryption_keys" {
  name                    = "${local.name_prefix}/app/encryption-keys"
  description             = "Application-level encryption keys for PII data"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name       = "${local.name_prefix}-app-encryption-keys"
    SecretType = "encryption-keys"
  })
}

resource "aws_secretsmanager_secret_version" "app_encryption_keys" {
  secret_id = aws_secretsmanager_secret.app_encryption_keys.id
  secret_string = jsonencode({
    current_key_id  = "v1"
    current_key     = random_bytes.app_encryption_key.base64
    algorithm       = "AES-256-GCM"
    created_at      = timestamp()
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

###############################################################################
# Resource Policy for Secrets (allow EKS IRSA roles)
###############################################################################

resource "aws_secretsmanager_secret_policy" "jwt_private_key" {
  secret_arn = aws_secretsmanager_secret.jwt_private_key.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTokenServiceRead"
        Effect = "Allow"
        Principal = {
          AWS = var.token_service_role_arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}
