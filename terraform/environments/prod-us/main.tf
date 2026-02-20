###############################################################################
# PROD-US Environment - Full production us-east-1
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
    key            = "environments/prod-us/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "ecommerce-ciam-terraform-locks"
    kms_key_id     = "alias/terraform-state-key"
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
      CostCenter  = "CIAM-PROD-US"
      Compliance  = "SOC2-PCI-GDPR"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

###############################################################################
# KMS (multi-region keys for global DB)
###############################################################################

module "kms" {
  source       = "../../modules/kms"
  project_name = var.project_name
  environment  = var.environment

  enable_multi_region_keys = true   # Needed for Aurora Global DB
  alarm_sns_arn            = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# Networking (full 3-AZ, redundant NAT gateways)
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
  single_nat_gateway      = false   # One per AZ for HA
  enable_vpc_flow_logs    = true
  flow_log_retention_days = 90
  kms_key_arn             = module.kms.s3_key_arn

  tags = var.common_tags
}

###############################################################################
# ECR (production - immutable, cross-account pull for prod-eu)
###############################################################################

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn                 = module.kms.s3_key_arn
  image_tag_mutability        = "IMMUTABLE"
  force_delete                = false
  enable_enhanced_scanning    = true
  enable_cross_account_access = var.prod_eu_account_id != ""
  cross_account_pull_arns     = var.prod_eu_account_id != "" ? [
    "arn:aws:iam::${var.prod_eu_account_id}:root"
  ] : []
  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# EKS (full production scale)
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
  endpoint_public_access = false

  on_demand_instance_types = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
  on_demand_min_size       = 3
  on_demand_max_size       = 20
  on_demand_desired_size   = 5

  spot_instance_types  = ["m6i.2xlarge", "m6a.2xlarge", "m5.2xlarge", "m5d.2xlarge", "m5n.2xlarge"]
  spot_min_size        = 2
  spot_max_size        = 40
  spot_desired_size    = 8

  log_retention_days = 90

  tags = var.common_tags
}

###############################################################################
# Aurora Global PostgreSQL (writer + 2 readers, Global DB enabled)
###############################################################################

module "aurora" {
  source       = "../../modules/aurora-global"
  project_name = var.project_name
  environment  = var.environment

  engine_version  = var.aurora_engine_version
  instance_class  = "db.r7g.xlarge"
  reader_count    = 2

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = var.db_master_password

  data_subnet_ids          = module.networking.private_data_subnet_ids
  aurora_security_group_id = module.networking.sg_aurora_id
  kms_key_arn              = module.kms.aurora_key_arn

  backup_retention_days      = 35
  deletion_protection        = true
  enable_global_db           = true   # Global DB for prod-eu secondary
  enable_enhanced_monitoring = true
  enable_autoscaling         = true
  autoscaling_max_replicas   = 5

  serverless_min_capacity = 2
  serverless_max_capacity = 64

  rotation_lambda_arn = var.secrets_rotation_lambda_arn
  alarm_sns_arn       = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# ElastiCache Redis (full cluster mode - 3 shards, 2 replicas each)
###############################################################################

module "redis" {
  source       = "../../modules/elasticache-redis"
  project_name = var.project_name
  environment  = var.environment

  engine_version     = var.redis_engine_version
  node_type          = "cache.r7g.xlarge"
  num_shards         = 3
  replicas_per_shard = 2

  data_subnet_ids         = module.networking.private_data_subnet_ids
  redis_security_group_id = module.networking.sg_elasticache_id
  kms_key_arn             = module.kms.redis_key_arn

  snapshot_retention_limit = 7
  enable_autoscaling       = true
  autoscaling_max_shards   = 10
  log_retention_days       = 90

  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# MSK Kafka (production - 3x brokers per AZ)
###############################################################################

module "kafka" {
  source       = "../../modules/msk-kafka"
  project_name = var.project_name
  environment  = var.environment

  kafka_version        = var.kafka_version
  broker_instance_type = "kafka.m5.xlarge"
  brokers_per_az       = 1
  broker_volume_size   = 500

  availability_zones    = var.availability_zones
  data_subnet_ids       = module.networking.private_data_subnet_ids
  msk_security_group_id = module.networking.sg_msk_id
  kms_key_arn           = module.kms.s3_key_arn

  log_retention_days = 30

  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# OpenSearch (production - 3 data nodes + dedicated masters)
###############################################################################

module "opensearch" {
  source       = "../../modules/opensearch"
  project_name = var.project_name
  environment  = var.environment

  opensearch_version = var.opensearch_version
  instance_type      = "r6g.xlarge.search"
  instance_count     = 3

  dedicated_master_type = "r6g.large.search"
  volume_size           = 200
  enable_ultrawarm      = true   # Cost-efficient warm storage for prod

  data_subnet_ids              = module.networking.private_data_subnet_ids
  opensearch_security_group_id = module.networking.sg_opensearch_id
  kms_key_arn                  = module.kms.s3_key_arn
  master_user_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  service_role_arns            = [module.eks.node_group_role_arn]

  create_service_linked_role = false
  log_retention_days         = 90
  alarm_sns_arn              = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# WAF + Shield Advanced (production security)
###############################################################################

module "waf" {
  source       = "../../modules/waf"
  project_name = var.project_name
  environment  = var.environment

  scope                  = "REGIONAL"
  enable_shield_advanced = var.enable_shield_advanced
  alb_arn                = var.alb_arn

  log_retention_days = 90
  alarm_sns_arn      = module.monitoring.critical_alerts_topic_arn

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

  # Replication to EU for GDPR compliance
  replica_region      = "eu-west-1"
  replica_kms_key_arn = var.eu_replica_kms_key_arn

  rotation_lambda_arn = var.secrets_rotation_lambda_arn

  tags = var.common_tags
}

###############################################################################
# AppConfig (production feature flags)
###############################################################################

module "appconfig" {
  source       = "../../modules/appconfig"
  project_name = var.project_name
  environment  = var.environment

  alarm_arns = [
    module.monitoring.critical_alerts_topic_arn
  ]

  feature_mfa_enabled                   = true
  feature_passwordless_enabled          = true
  feature_social_login_enabled          = true
  feature_fraud_detection_enabled       = true
  feature_session_binding_enabled       = true
  feature_progressive_profiling_enabled = true
  feature_account_linking_enabled       = true

  cors_allowed_origins = [
    "https://${var.domain_name}",
    "https://app.${var.domain_name}",
    "https://admin.${var.domain_name}"
  ]

  tags = var.common_tags
}

###############################################################################
# CloudFront (global CDN, Shield Advanced)
###############################################################################

module "cloudfront" {
  source       = "../../modules/cloudfront"
  project_name = var.project_name
  environment  = var.environment

  domain_name               = var.domain_name
  additional_domain_names   = ["app.${var.domain_name}", "admin.${var.domain_name}"]
  route53_zone_id           = var.route53_zone_id
  alb_dns_name              = var.alb_dns_name
  jwt_public_key_secret_arn = module.secrets.jwt_private_key_secret_arn
  s3_kms_key_arn            = module.kms.s3_key_arn
  price_class               = "PriceClass_All"

  tags = var.common_tags

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

###############################################################################
# Monitoring (full production monitoring)
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
  domain_name           = var.domain_name
  log_retention_days    = 90

  canary_test_username = var.canary_test_username
  canary_test_password = var.canary_test_password

  tags = var.common_tags
}
