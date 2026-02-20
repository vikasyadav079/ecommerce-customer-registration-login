###############################################################################
# DEV Environment - Small instances, single-AZ config, cost-optimized
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
    key            = "environments/dev/terraform.tfstate"
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
      CostCenter  = "CIAM-DEV"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

###############################################################################
# KMS Keys (created first - used by most modules)
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
# Networking (single NAT gateway in dev)
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

  enable_nat_gateway    = true
  single_nat_gateway    = true   # Cost saving - single NAT in dev
  enable_vpc_flow_logs  = true
  flow_log_retention_days = 14
  kms_key_arn           = module.kms.s3_key_arn

  tags = var.common_tags
}

###############################################################################
# ECR Repositories
###############################################################################

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn          = module.kms.s3_key_arn
  image_tag_mutability = "MUTABLE"   # Allow mutable tags in dev
  force_delete         = true        # Allow teardown in dev

  enable_enhanced_scanning    = false  # Not needed in dev
  enable_cross_account_access = false

  tags = var.common_tags
}

###############################################################################
# EKS Cluster (minimal footprint in dev)
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

  kms_key_arn             = module.kms.eks_key_arn
  endpoint_public_access  = true   # Easier dev access
  public_access_cidrs     = var.developer_cidr_blocks

  on_demand_instance_types = ["t3.medium", "t3a.medium"]
  on_demand_min_size       = 1
  on_demand_max_size       = 4
  on_demand_desired_size   = 2

  spot_instance_types  = ["t3.large", "t3a.large", "t3.xlarge"]
  spot_min_size        = 0
  spot_max_size        = 6
  spot_desired_size    = 2

  log_retention_days = 7

  tags = var.common_tags
}

###############################################################################
# Aurora PostgreSQL (single writer, no reader - dev)
###############################################################################

module "aurora" {
  source       = "../../modules/aurora-global"
  project_name = var.project_name
  environment  = var.environment

  engine_version  = var.aurora_engine_version
  instance_class  = "db.t4g.medium"   # Small dev instance
  reader_count    = 0                  # No readers in dev

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = var.db_master_password

  data_subnet_ids          = module.networking.private_data_subnet_ids
  aurora_security_group_id = module.networking.sg_aurora_id
  kms_key_arn              = module.kms.aurora_key_arn

  backup_retention_days      = 1
  deletion_protection        = false
  enable_global_db           = false
  enable_enhanced_monitoring = false
  enable_autoscaling         = false

  serverless_min_capacity = 0.5
  serverless_max_capacity = 4

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# ElastiCache Redis (single shard, minimal replicas - dev)
###############################################################################

module "redis" {
  source       = "../../modules/elasticache-redis"
  project_name = var.project_name
  environment  = var.environment

  engine_version     = var.redis_engine_version
  node_type          = "cache.t4g.small"   # Smallest node in dev
  num_shards         = 1
  replicas_per_shard = 1

  data_subnet_ids         = module.networking.private_data_subnet_ids
  redis_security_group_id = module.networking.sg_elasticache_id
  kms_key_arn             = module.kms.redis_key_arn

  snapshot_retention_limit = 1
  enable_autoscaling       = false
  log_retention_days       = 7

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# MSK Kafka (minimal broker config - dev)
###############################################################################

module "kafka" {
  source       = "../../modules/msk-kafka"
  project_name = var.project_name
  environment  = var.environment

  kafka_version        = var.kafka_version
  broker_instance_type = "kafka.t3.small"
  brokers_per_az       = 1
  broker_volume_size   = 50

  availability_zones = [var.availability_zones[0]]  # Single AZ in dev
  data_subnet_ids    = [module.networking.private_data_subnet_ids[0]]
  msk_security_group_id = module.networking.sg_msk_id
  kms_key_arn           = module.kms.s3_key_arn

  log_retention_days = 7

  alarm_sns_arn = module.monitoring.warning_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# OpenSearch (single node - dev)
###############################################################################

module "opensearch" {
  source       = "../../modules/opensearch"
  project_name = var.project_name
  environment  = var.environment

  opensearch_version = var.opensearch_version
  instance_type      = "t3.small.search"
  instance_count     = 1

  volume_size          = 20
  enable_ultrawarm     = false

  data_subnet_ids              = [module.networking.private_data_subnet_ids[0]]
  opensearch_security_group_id = module.networking.sg_opensearch_id
  kms_key_arn                  = module.kms.s3_key_arn
  master_user_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

  create_service_linked_role = var.create_opensearch_slr
  log_retention_days         = 7
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
  admin_allowed_ips      = var.developer_cidr_blocks
  log_retention_days     = 14
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

  kms_key_arn           = module.kms.secrets_manager_key_arn
  db_host               = module.aurora.cluster_endpoint
  db_reader_host        = module.aurora.cluster_reader_endpoint
  db_name               = var.db_name
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

  feature_mfa_enabled                   = false   # Disabled in dev for ease
  feature_passwordless_enabled          = true
  feature_social_login_enabled          = true
  feature_fraud_detection_enabled       = false
  feature_session_binding_enabled       = false
  feature_progressive_profiling_enabled = true
  feature_account_linking_enabled       = true

  cors_allowed_origins = ["http://localhost:3000", "http://localhost:8080", "https://dev.${var.domain_name}"]

  tags = var.common_tags
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
  domain_name           = "dev.${var.domain_name}"
  log_retention_days    = 7

  tags = var.common_tags
}

###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}
