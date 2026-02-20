###############################################################################
# KMS Module - CMKs for JWT Signing, Aurora, Redis, S3, EKS Secrets
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# KMS Key Policy Template
###############################################################################

data "aws_iam_policy_document" "key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow CloudWatch Logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

###############################################################################
# JWT Signing Key (Asymmetric RSA-4096)
###############################################################################

resource "aws_kms_key" "jwt_signing" {
  description              = "CMK for JWT signing and verification - ${local.name_prefix}"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"
  enable_key_rotation      = false  # Asymmetric keys do not support auto-rotation

  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = var.enable_multi_region_keys

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow JWT Sign"
        Effect = "Allow"
        Principal = {
          AWS = var.jwt_signer_role_arns
        }
        Action   = ["kms:Sign", "kms:Verify", "kms:GetPublicKey", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-jwt-signing-key"
    Purpose = "jwt-signing"
    KeyType = "asymmetric-rsa-4096"
  })
}

resource "aws_kms_alias" "jwt_signing" {
  name          = "alias/${local.name_prefix}-jwt-signing"
  target_key_id = aws_kms_key.jwt_signing.key_id
}

###############################################################################
# Aurora Encryption Key (Symmetric AES-256)
###############################################################################

resource "aws_kms_key" "aurora" {
  description              = "CMK for Aurora PostgreSQL encryption - ${local.name_prefix}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = var.enable_multi_region_keys

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS Service"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-aurora-key"
    Purpose = "aurora-encryption"
    KeyType = "symmetric-aes-256"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${local.name_prefix}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

###############################################################################
# Redis Encryption Key (Symmetric AES-256)
###############################################################################

resource "aws_kms_key" "redis" {
  description              = "CMK for ElastiCache Redis encryption - ${local.name_prefix}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = var.enable_multi_region_keys

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ElastiCache Service"
        Effect = "Allow"
        Principal = {
          Service = "elasticache.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-redis-key"
    Purpose = "redis-encryption"
    KeyType = "symmetric-aes-256"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${local.name_prefix}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

###############################################################################
# S3 Encryption Key (Symmetric AES-256)
###############################################################################

resource "aws_kms_key" "s3" {
  description              = "CMK for S3 bucket encryption - ${local.name_prefix}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = var.enable_multi_region_keys

  policy = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-s3-key"
    Purpose = "s3-encryption"
    KeyType = "symmetric-aes-256"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.name_prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

###############################################################################
# EKS Secrets Encryption Key
###############################################################################

resource "aws_kms_key" "eks" {
  description              = "CMK for EKS Kubernetes secrets encryption - ${local.name_prefix}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ListGrants",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-eks-key"
    Purpose = "eks-secrets-encryption"
    KeyType = "symmetric-aes-256"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

###############################################################################
# Secrets Manager Encryption Key
###############################################################################

resource "aws_kms_key" "secrets_manager" {
  description              = "CMK for Secrets Manager encryption - ${local.name_prefix}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true
  multi_region             = var.enable_multi_region_keys

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-secrets-manager-key"
    Purpose = "secrets-manager-encryption"
    KeyType = "symmetric-aes-256"
  })
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${local.name_prefix}-secrets-manager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

###############################################################################
# Terraform State Key
###############################################################################

resource "aws_kms_key" "terraform_state" {
  description              = "CMK for Terraform state S3 bucket encryption"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  rotation_period_in_days  = 365

  deletion_window_in_days  = 30
  is_enabled               = true

  policy = data.aws_iam_policy_document.key_policy.json

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-terraform-state-key"
    Purpose = "terraform-state-encryption"
  })
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state-key"
  target_key_id = aws_kms_key.terraform_state.key_id
}

###############################################################################
# CloudTrail KMS Key Monitoring
###############################################################################

resource "aws_cloudwatch_metric_alarm" "kms_key_disabled" {
  for_each = {
    jwt       = aws_kms_key.jwt_signing.key_id
    aurora    = aws_kms_key.aurora.key_id
    redis     = aws_kms_key.redis.key_id
    eks       = aws_kms_key.eks.key_id
    s3        = aws_kms_key.s3.key_id
  }

  alarm_name          = "${local.name_prefix}-kms-${each.key}-disabled-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DisableKey"
  namespace           = "AWS/KMS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "KMS key ${each.key} was disabled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    KeyId = each.value
  }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  tags          = var.tags
}
