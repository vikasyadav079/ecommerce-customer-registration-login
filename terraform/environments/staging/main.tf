###############################################################################
# STAGING Environment - Prod-like architecture, reduced scale
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
    key            = "environments/staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ecommerce-ciam-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Team        = "Platform-Engineering"
      CostCenter  = "CIAM-STAGING"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

###############################################################################
# KMS
###############################################################################

module "kms" {
  source       = "../../modules/kms"
  project_name = var.project_name
  environment  = var.environment

  enable_multi_region_keys = false
  jwt_signer_role_arns     = []

  tags = var.common_tags
}

###############################################################################
# Networking (3 AZs, dedicated NAT per AZ - prod-like)
###############################################################################

module "networking" {
  source       = "../../modules/networking"
  project_name = var.project_name
  environment  = var.environment

  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs

  enable_nat_gateway      = true
  single_nat_gateway      = false   # Prod-like: one per AZ
  enable_vpc_flow_logs    = true
  flow_log_retention_days = 30
  kms_key_arn             = module.kms.s3_key_arn

  tags = var.common_tags
}

###############################################################################
# ECR
###############################################################################

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn          = module.kms.s3_key_arn
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  enable_enhanced_scanning = true

  tags = var.common_tags
}

###############################################################################
# EKS (reduced scale but prod-like topology)
###############################################################################

module "eks" {
  source       = "../../modules/eks-cluster"
  project_name = var.project_name
  environment  = var.environment

  kubernetes_version     = var.kubernetes_version
  vpc_id                 = module.networking.vpc_id
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  public_subnet_ids      = module.networking.public_subnet_ids

  cluster_security_group_id = module.networking.sg_eks_cluster_id
  node_security_group_id    = module.networking.sg_eks_nodes_id

  kms_key_arn            = module.kms.eks_key_arn
  endpoint_public_access = false  # Private endpoint in staging

  on_demand_instance_types = ["m6i.large", "m6a.large", "m5.large"]
  on_demand_min_size       = 2
  on_demand_max_size       = 8
  on_demand_desired_size   = 3

  spot_instance_types  = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
  spot_min_size        = 0
  spot_max_size        = 12
  spot_desired_size    = 3

  log_retention_days = 30

  tags = var.common_tags
}

###############################################################################
# Aurora (writer + 1 reader - staging)
###############################################################################

module "aurora" {
  source       = "../../modules/aurora-global"
  project_name = var.project_name
  environment  = var.environment

  engine_version  = var.aurora_engine_version
  instance_class  = "db.r7g.large"
  reader_count    = 1

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = var.db_master_password

  data_subnet_ids          = module.networking.private_data_subnet_ids
  aurora_security_group_id = module.networking.sg_aurora_id
  kms_key_arn              = module.kms.aurora_key_arn

  backup_retention_days      = 7
  deletion_protection        = true
  enable_global_db           = false
  enable_enhanced_monitoring = true
  enable_autoscaling         = true
  autoscaling_max_replicas   = 3

  serverless_min_capacity = 1
  serverless_max_capacity = 16

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# Redis (3 shards, 1 replica each - staging)
###############################################################################

module "redis" {
  source       = "../../modules/elasticache-redis"
  project_name = var.project_name
  environment  = var.environment

  engine_version     = var.redis_engine_version
  node_type          = "cache.r7g.large"
  num_shards         = 2
  replicas_per_shard = 1

  data_subnet_ids         = module.networking.private_data_subnet_ids
  redis_security_group_id = module.networking.sg_elasticache_id
  kms_key_arn             = module.kms.redis_key_arn

  snapshot_retention_limit = 3
  enable_autoscaling       = true
  autoscaling_max_shards   = 6
  log_retention_days       = 30

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# MSK Kafka (3-broker cluster - staging)
###############################################################################

module "kafka" {
  source       = "../../modules/msk-kafka"
  project_name = var.project_name
  environment  = var.environment

  kafka_version        = var.kafka_version
  broker_instance_type = "kafka.m5.large"
  brokers_per_az       = 1
  broker_volume_size   = 100

  availability_zones    = var.availability_zones
  data_subnet_ids       = module.networking.private_data_subnet_ids
  msk_security_group_id = module.networking.sg_msk_id
  kms_key_arn           = module.kms.s3_key_arn

  log_retention_days = 14

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# OpenSearch (3-node cluster - staging)
###############################################################################

module "opensearch" {
  source       = "../../modules/opensearch"
  project_name = var.project_name
  environment  = var.environment

  opensearch_version = var.opensearch_version
  instance_type      = "r6g.large.search"
  instance_count     = 3

  volume_size      = 100
  enable_ultrawarm = false

  data_subnet_ids              = module.networking.private_data_subnet_ids
  opensearch_security_group_id = module.networking.sg_opensearch_id
  kms_key_arn                  = module.kms.s3_key_arn
  master_user_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

  create_service_linked_role = var.create_opensearch_slr
  log_retention_days         = 14
  alarm_sns_arn              = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# WAF
###############################################################################

module "waf" {
  source       = "../../modules/waf"
  project_name = var.project_name
  environment  = var.environment

  scope                  = "REGIONAL"
  enable_shield_advanced = false
  log_retention_days     = 30
  alarm_sns_arn          = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# Secrets Manager
###############################################################################

module "secrets" {
  source       = "../../modules/secrets-manager"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn                  = module.kms.secrets_manager_key_arn
  db_host                      = module.aurora.cluster_endpoint
  db_reader_host               = module.aurora.cluster_reader_endpoint
  db_name                      = var.db_name
  redis_configuration_endpoint = module.redis.configuration_endpoint_address

  tags = var.common_tags
}

###############################################################################
# AppConfig
###############################################################################

module "appconfig" {
  source       = "../../modules/appconfig"
  project_name = var.project_name
  environment  = var.environment

  feature_mfa_enabled                   = true
  feature_passwordless_enabled          = true
  feature_social_login_enabled          = true
  feature_fraud_detection_enabled       = true   # Test in staging
  feature_session_binding_enabled       = true
  feature_progressive_profiling_enabled = true
  feature_account_linking_enabled       = true

  cors_allowed_origins = ["https://staging.${var.domain_name}", "https://qa.${var.domain_name}"]

  tags = var.common_tags
}

###############################################################################
# CloudFront
###############################################################################

module "cloudfront" {
  source       = "../../modules/cloudfront"
  project_name = var.project_name
  environment  = var.environment

  domain_name               = "staging.${var.domain_name}"
  route53_zone_id           = var.route53_zone_id
  alb_dns_name              = var.alb_dns_name
  waf_web_acl_arn           = ""  # WAF for CF must be in us-east-1 - configure separately
  jwt_public_key_secret_arn = module.secrets.jwt_private_key_secret_arn
  s3_kms_key_arn            = module.kms.s3_key_arn
  price_class               = "PriceClass_100"  # NA + EU only for staging

  tags = var.common_tags

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

###############################################################################
# Monitoring
###############################################################################

module "monitoring" {
  source       = "../../modules/monitoring"
  project_name = var.project_name
  environment  = var.environment

  alarm_email_endpoints = var.alarm_email_endpoints
  kms_key_arn           = module.kms.s3_key_arn
  eks_cluster_name      = module.eks.cluster_name
  aurora_cluster_id     = module.aurora.cluster_id
  redis_cluster_id      = module.redis.replication_group_id
  waf_acl_name          = module.waf.web_acl_name
  domain_name           = "staging.${var.domain_name}"
  log_retention_days    = 30

  tags = var.common_tags
}
