###############################################################################
# ECR Repositories - Per Microservice, Lifecycle Policies, Image Scanning
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # CIAM microservices
  microservices = toset([
    "identity-service",
    "auth-service",
    "token-service",
    "session-service",
    "user-service",
    "profile-service",
    "password-service",
    "mfa-service",
    "notification-service",
    "audit-service",
    "consent-service",
    "risk-engine",
    "api-gateway",
    "admin-service",
    "oauth2-server",
    "saml-provider",
    "webhook-service",
    "migration-service"
  ])
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# ECR Repositories
###############################################################################

resource "aws_ecr_repository" "microservices" {
  for_each = local.microservices

  name                 = "${local.name_prefix}/${each.value}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}/${each.value}"
    ServiceName = each.value
  })
}

###############################################################################
# ECR Lifecycle Policies
###############################################################################

resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = aws_ecr_repository.microservices
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images tagged with 'prod-*'"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 release candidates tagged with 'rc-*'"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["rc-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 5 staging images tagged with 'staging-*'"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 5
        description  = "Keep at most 50 any images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

###############################################################################
# ECR Repository Policy (cross-account access for multi-env setup)
###############################################################################

resource "aws_ecr_repository_policy" "microservices" {
  for_each   = var.enable_cross_account_access ? aws_ecr_repository.microservices : {}
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPull"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_pull_arns
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages"
        ]
      }
    ]
  })
}

###############################################################################
# ECR Scanning Configuration (Enhanced Scanning)
###############################################################################

resource "aws_ecr_registry_scanning_configuration" "main" {
  count     = var.enable_enhanced_scanning ? 1 : 0
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "${var.project_name}/*"
      filter_type = "WILDCARD"
    }
  }
}

###############################################################################
# ECR Registry-Level Policies
###############################################################################

resource "aws_ecr_registry_policy" "main" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReplicationAccessCrossAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:CreateRepository",
          "ecr:ReplicateImage"
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

###############################################################################
# ECR Pull Through Cache Rules (for public upstream images)
###############################################################################

resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_pull_through_cache_rule" "quay" {
  count                 = var.enable_quay_pull_through ? 1 : 0
  ecr_repository_prefix = "quay"
  upstream_registry_url = "quay.io"
  credential_arn        = var.quay_credential_arn
}

###############################################################################
# CloudWatch Alarms for ECR Scanning Results
###############################################################################

resource "aws_cloudwatch_event_rule" "ecr_scan_finding" {
  name        = "${local.name_prefix}-ecr-critical-finding"
  description = "Alert on ECR image scan CRITICAL findings"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      "scan-status"        = ["COMPLETE"]
      "finding-severity-counts" = {
        CRITICAL = [{ numeric = [">", 0] }]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ecr_scan_finding" {
  count     = var.alarm_sns_arn != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.ecr_scan_finding.name
  target_id = "ECRScanFindingAlert"
  arn       = var.alarm_sns_arn
}
