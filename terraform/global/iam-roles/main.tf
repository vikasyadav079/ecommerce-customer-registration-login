###############################################################################
# Global IAM Roles - Least-privilege per service with IRSA bindings
###############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "ecommerce-ciam-terraform-state"
    key            = "global/iam-roles/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ecommerce-ciam-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
  oidc_host    = replace(var.eks_oidc_provider_url, "https://", "")
}

###############################################################################
# Helper: IRSA Trust Policy
###############################################################################

data "aws_iam_policy_document" "irsa_trust" {
  for_each = var.irsa_service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

###############################################################################
# Auth Service IRSA Role
###############################################################################

resource "aws_iam_role" "auth_service" {
  name        = "${var.project_name}-${var.environment}-auth-service"
  description = "IRSA role for authentication service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:auth-service"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "auth_service" {
  name        = "${var.project_name}-${var.environment}-auth-service-policy"
  description = "Least-privilege policy for auth service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerReadAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/jwt/*",
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/db/ciam-service*",
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/redis/*"
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [
          "arn:aws:kms:${local.region}:${local.account_id}:key/*"
        ]
        Condition = {
          StringLike = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "KMSSignVerify"
        Effect = "Allow"
        Action = ["kms:Sign", "kms:Verify", "kms:GetPublicKey"]
        Resource = [var.jwt_signing_key_arn]
      },
      {
        Sid    = "AppConfigRead"
        Effect = "Allow"
        Action = [
          "appconfig:GetConfiguration",
          "appconfig:GetLatestConfiguration",
          "appconfig:StartConfigurationSession",
          "appconfigdata:GetLatestConfiguration",
          "appconfigdata:StartConfigurationSession"
        ]
        Resource = "arn:aws:appconfig:${local.region}:${local.account_id}:application/${var.appconfig_app_id}/*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "auth_service" {
  role       = aws_iam_role.auth_service.name
  policy_arn = aws_iam_policy.auth_service.arn
}

###############################################################################
# Token Service IRSA Role (JWT signing operations)
###############################################################################

resource "aws_iam_role" "token_service" {
  name        = "${var.project_name}-${var.environment}-token-service"
  description = "IRSA role for JWT token service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:token-service"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "token_service" {
  name        = "${var.project_name}-${var.environment}-token-service-policy"
  description = "Least-privilege policy for token service (JWT signing)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "JWTKeySignVerify"
        Effect = "Allow"
        Action = ["kms:Sign", "kms:Verify", "kms:GetPublicKey", "kms:DescribeKey"]
        Resource = var.jwt_signing_key_arn
      },
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/jwt/*"
        ]
      },
      {
        Sid    = "RedisAccess"
        Effect = "Allow"
        Action = ["elasticache:DescribeReplicationGroups"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "token_service" {
  role       = aws_iam_role.token_service.name
  policy_arn = aws_iam_policy.token_service.arn
}

###############################################################################
# User Service IRSA Role
###############################################################################

resource "aws_iam_role" "user_service" {
  name        = "${var.project_name}-${var.environment}-user-service"
  description = "IRSA role for user management service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:user-service"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "user_service" {
  name        = "${var.project_name}-${var.environment}-user-service-policy"
  description = "Least-privilege policy for user service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DBSecretsRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/db/*"
        ]
      },
      {
        Sid    = "S3ProfileImages"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-user-assets/*"
      },
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-user-assets"
      },
      {
        Sid    = "SESEmailValidation"
        Effect = "Allow"
        Action = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "arn:aws:ses:${local.region}:${local.account_id}:identity/*"
      },
      {
        Sid    = "KafkaPublish"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.project_name}-${var.environment}-msk/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.project_name}-${var.environment}-msk/*/user-events"
        ]
      },
      {
        Sid    = "OpenSearchIndexing"
        Effect = "Allow"
        Action = ["es:ESHttpPut", "es:ESHttpPost", "es:ESHttpGet"]
        Resource = "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "user_service" {
  role       = aws_iam_role.user_service.name
  policy_arn = aws_iam_policy.user_service.arn
}

###############################################################################
# Notification Service IRSA Role
###############################################################################

resource "aws_iam_role" "notification_service" {
  name        = "${var.project_name}-${var.environment}-notification-service"
  description = "IRSA role for notification service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:notification-service"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "notification_service" {
  name        = "${var.project_name}-${var.environment}-notification-service-policy"
  description = "Least-privilege policy for notification service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SESEmailSend"
        Effect = "Allow"
        Action = ["ses:SendEmail", "ses:SendRawEmail", "ses:SendTemplatedEmail"]
        Resource = [
          "arn:aws:ses:${local.region}:${local.account_id}:identity/*",
          "arn:aws:ses:${local.region}:${local.account_id}:template/*"
        ]
      },
      {
        Sid    = "SNSSMSSend"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = "*"
        Condition = {
          StringEquals = { "sns:Type" = "sms" }
        }
      },
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/email/*",
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/sms/*"
        ]
      },
      {
        Sid    = "KafkaConsume"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.project_name}-${var.environment}-msk/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.project_name}-${var.environment}-msk/*/notification-requests",
          "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.project_name}-${var.environment}-msk/*/notification-service-*"
        ]
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "notification_service" {
  role       = aws_iam_role.notification_service.name
  policy_arn = aws_iam_policy.notification_service.arn
}

###############################################################################
# Audit Service IRSA Role
###############################################################################

resource "aws_iam_role" "audit_service" {
  name        = "${var.project_name}-${var.environment}-audit-service"
  description = "IRSA role for audit logging service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:audit-service"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "audit_service" {
  name        = "${var.project_name}-${var.environment}-audit-service-policy"
  description = "Least-privilege policy for audit service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchWrite"
        Effect = "Allow"
        Action = ["es:ESHttpPut", "es:ESHttpPost", "es:ESHttpGet", "es:ESHttpDelete"]
        Resource = [
          "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/audit-logs-*",
          "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/_bulk",
          "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/_cat/*"
        ]
      },
      {
        Sid    = "S3AuditLongTerm"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-audit-logs/*"
      },
      {
        Sid    = "KafkaConsume"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.project_name}-${var.environment}-msk/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.project_name}-${var.environment}-msk/*/audit-log",
          "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.project_name}-${var.environment}-msk/*/audit-service-*"
        ]
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "audit_service" {
  role       = aws_iam_role.audit_service.name
  policy_arn = aws_iam_policy.audit_service.arn
}

###############################################################################
# Risk Engine IRSA Role
###############################################################################

resource "aws_iam_role" "risk_engine" {
  name        = "${var.project_name}-${var.environment}-risk-engine"
  description = "IRSA role for fraud and risk assessment engine"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:risk-engine"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "risk_engine" {
  name        = "${var.project_name}-${var.environment}-risk-engine-policy"
  description = "Least-privilege policy for risk engine"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchRead"
        Effect = "Allow"
        Action = ["es:ESHttpGet", "es:ESHttpPost"]
        Resource = [
          "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/auth-events-*",
          "arn:aws:es:${local.region}:${local.account_id}:domain/${var.project_name}-${var.environment}-os/risk-signals-*"
        ]
      },
      {
        Sid    = "SageMakerInference"
        Effect = "Allow"
        Action = ["sagemaker:InvokeEndpoint"]
        Resource = "arn:aws:sagemaker:${local.region}:${local.account_id}:endpoint/${var.project_name}-${var.environment}-risk-model"
      },
      {
        Sid    = "KafkaConsumePublish"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = [
          "arn:aws:kafka:${local.region}:${local.account_id}:cluster/${var.project_name}-${var.environment}-msk/*",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.project_name}-${var.environment}-msk/*/risk-signals",
          "arn:aws:kafka:${local.region}:${local.account_id}:topic/${var.project_name}-${var.environment}-msk/*/auth-events",
          "arn:aws:kafka:${local.region}:${local.account_id}:group/${var.project_name}-${var.environment}-msk/*/risk-engine-*"
        ]
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "risk_engine" {
  role       = aws_iam_role.risk_engine.name
  policy_arn = aws_iam_policy.risk_engine.arn
}

###############################################################################
# API Gateway IRSA Role (routing layer)
###############################################################################

resource "aws_iam_role" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api-gateway"
  description = "IRSA role for internal API gateway service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.eks_oidc_provider_arn }
        Condition = {
          StringEquals = {
            "${local.oidc_host}:sub" = "system:serviceaccount:ciam:api-gateway"
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "api_gateway" {
  name        = "${var.project_name}-${var.environment}-api-gateway-policy"
  description = "Least-privilege policy for API gateway"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/jwt/public*",
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}-${var.environment}/oauth2/*"
        ]
      },
      {
        Sid    = "AppConfigRead"
        Effect = "Allow"
        Action = [
          "appconfigdata:GetLatestConfiguration",
          "appconfigdata:StartConfigurationSession"
        ]
        Resource = "arn:aws:appconfig:${local.region}:${local.account_id}:application/${var.appconfig_app_id}/*"
      },
      {
        Sid    = "WAFCheckIP"
        Effect = "Allow"
        Action = ["wafv2:GetIPSet"]
        Resource = "arn:aws:wafv2:${local.region}:${local.account_id}:regional/ipset/*"
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "CIAMPlatform" }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "api_gateway" {
  role       = aws_iam_role.api_gateway.name
  policy_arn = aws_iam_policy.api_gateway.arn
}

###############################################################################
# CI/CD Pipeline Role (GitHub Actions / CodePipeline)
###############################################################################

resource "aws_iam_role" "cicd_deploy" {
  name        = "${var.project_name}-${var.environment}-cicd-deploy"
  description = "Role for CI/CD pipeline to deploy to EKS and update ECR"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = var.github_actions_oidc_provider_arn }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cicd_deploy" {
  name        = "${var.project_name}-${var.environment}-cicd-deploy-policy"
  description = "CI/CD deployment permissions - ECR push, EKS deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${var.project_name}-${var.environment}/*"
      },
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${local.region}:${local.account_id}:cluster/${var.project_name}-${var.environment}-eks"
      },
      {
        Sid    = "AppConfigDeploy"
        Effect = "Allow"
        Action = [
          "appconfig:CreateDeployment",
          "appconfig:GetDeployment",
          "appconfig:CreateHostedConfigurationVersion"
        ]
        Resource = "arn:aws:appconfig:${local.region}:${local.account_id}:application/${var.appconfig_app_id}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cicd_deploy" {
  role       = aws_iam_role.cicd_deploy.name
  policy_arn = aws_iam_policy.cicd_deploy.arn
}

###############################################################################
# GitHub Actions OIDC Provider (global, once per account)
###############################################################################

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}
