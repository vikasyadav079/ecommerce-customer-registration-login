###############################################################################
# S3 State Backend + DynamoDB Lock Table
# NOTE: Apply this FIRST before any other Terraform configuration
# Run with: terraform init && terraform apply
# Then bootstrap other modules pointing to this backend
###############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # IMPORTANT: This module uses local state initially.
  # After first apply, you can migrate state to S3 backend if desired.
  # DO NOT set an S3 backend here - it creates a chicken-and-egg problem.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "ecommerce-ciam"
      ManagedBy = "Terraform"
      Team      = "Platform-Engineering"
      Purpose   = "TerraformStateBackend"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# KMS Key for State Encryption (independent of main KMS module)
###############################################################################

resource "aws_kms_key" "terraform_state" {
  description              = "CMK for Terraform state S3 bucket encryption"
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
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "terraform-state-kms-key"
    Purpose = "terraform-state-encryption"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state-key"
  target_key_id = aws_kms_key.terraform_state.key_id
}

###############################################################################
# S3 Bucket for Terraform State
###############################################################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  # IMPORTANT: Prevent accidental deletion of this critical infrastructure
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-terraform-state"
    Purpose = "TerraformRemoteState"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10  # Keep last 10 non-current versions
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  name   = "EntireStateFiles"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "state-access-logs/"
}

resource "aws_s3_bucket_notification" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  topic {
    topic_arn     = aws_sns_topic.state_changes.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix = "environments/prod"
  }
}

###############################################################################
# S3 Bucket for State Access Logs
###############################################################################

resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "${var.project_name}-terraform-state-logs-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-terraform-state-logs"
    Purpose = "TerraformStateAccessLogs"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket                  = aws_s3_bucket.terraform_state_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    expiration {
      days = 365
    }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "terraform_state_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.terraform_state_logs]
  bucket     = aws_s3_bucket.terraform_state_logs.id
  acl        = "log-delivery-write"
}

###############################################################################
# S3 Bucket Policy - Restrict to account only + enforce TLS
###############################################################################

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonTLS"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "RestrictToAccount"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

###############################################################################
# DynamoDB Table for State Locking
###############################################################################

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-terraform-locks"
    Purpose = "TerraformStateLocking"
  }
}

###############################################################################
# SNS Topic for State Change Notifications
###############################################################################

resource "aws_sns_topic" "state_changes" {
  name              = "${var.project_name}-terraform-state-changes"
  kms_master_key_id = aws_kms_key.terraform_state.id

  tags = {
    Name    = "${var.project_name}-state-changes"
    Purpose = "TerraformStateNotifications"
  }
}

resource "aws_sns_topic_subscription" "state_changes_email" {
  for_each  = toset(var.state_change_notification_emails)
  topic_arn = aws_sns_topic.state_changes.arn
  protocol  = "email"
  endpoint  = each.value
}

###############################################################################
# IAM Policy for Terraform state access (attach to CI/CD roles)
###############################################################################

resource "aws_iam_policy" "terraform_state_access" {
  name        = "${var.project_name}-terraform-state-access"
  description = "Allows Terraform backend operations on state S3 + DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "DynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.terraform_state_lock.arn
      },
      {
        Sid    = "KMSStateKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.terraform_state.arn
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-terraform-state-access"
    Purpose = "TerraformCICD"
  }
}

###############################################################################
# CloudWatch Alarm: Detect unauthorized state access
###############################################################################

resource "aws_cloudwatch_log_metric_filter" "state_access" {
  count          = var.cloudtrail_log_group != "" ? 1 : 0
  name           = "${var.project_name}-terraform-state-access"
  log_group_name = var.cloudtrail_log_group
  pattern        = "{ ($.eventSource = \"s3.amazonaws.com\") && ($.requestParameters.bucketName = \"${aws_s3_bucket.terraform_state.bucket}\") && ($.errorCode = \"AccessDenied\") }"

  metric_transformation {
    name          = "TerraformStateUnauthorizedAccess"
    namespace     = "SecurityMetrics"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "state_unauthorized_access" {
  count               = var.cloudtrail_log_group != "" ? 1 : 0
  alarm_name          = "${var.project_name}-terraform-state-unauthorized-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TerraformStateUnauthorizedAccess"
  namespace           = "SecurityMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Unauthorized access to Terraform state bucket detected"
  treat_missing_data  = "notBreaching"

  alarm_actions = length(var.state_change_notification_emails) > 0 ? [aws_sns_topic.state_changes.arn] : []

  tags = {
    Purpose = "TerraformStateSecurity"
  }
}
