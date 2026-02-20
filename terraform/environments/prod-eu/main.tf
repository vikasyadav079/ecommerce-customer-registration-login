###############################################################################
# PROD-EU Environment - GDPR Data Residency eu-west-1
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
    key            = "environments/prod-eu/terraform.tfstate"
    region         = "us-east-1"  # State always in us-east-1
    encrypt        = true
    dynamodb_table = "ecommerce-ciam-terraform-locks"
    kms_key_id     = "alias/terraform-state-key"
  }
}

provider "aws" {
  region = "eu-west-1"   # EU region for GDPR data residency
  default_tags {
    tags = {
      Project       = var.project_name
      Environment   = var.environment
      ManagedBy     = "Terraform"
      Team          = "Platform-Engineering"
      CostCenter    = "CIAM-PROD-EU"
      DataResidency = "EU-GDPR"
      Compliance    = "GDPR,SOC2"
    }
  }
}

# us-east-1 provider for CloudFront ACM and global resources
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# Remote State - prod-us (to reference Global DB ARN)
###############################################################################

data "terraform_remote_state" "prod_us" {
  count   = var.link_to_prod_us ? 1 : 0
  backend = "s3"
  config = {
    bucket = "ecommerce-ciam-terraform-state"
    key    = "environments/prod-us/terraform.tfstate"
    region = "us-east-1"
  }
}

###############################################################################
# KMS (EU replica keys for multi-region encryption)
###############################################################################

module "kms" {
  source       = "../../modules/kms"
  project_name = var.project_name
  environment  = var.environment

  enable_multi_region_keys = true   # Multi-region replicas from prod-us
  alarm_sns_arn            = module.monitoring.critical_alerts_topic_arn

  tags = merge(var.common_tags, {
    DataResidency = "EU"
    GDPRScope     = "true"
  })
}

###############################################################################
# Networking (EU VPC - non-overlapping CIDR)
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
  single_nat_gateway      = false
  enable_vpc_flow_logs    = true
  flow_log_retention_days = 365   # GDPR compliance - 1 year
  kms_key_arn             = module.kms.s3_key_arn

  tags = var.common_tags
}

###############################################################################
# ECR (EU region - pull from prod-us primary registry or local)
###############################################################################

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn          = module.kms.s3_key_arn
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  enable_enhanced_scanning = true

  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# EKS (EU cluster - full production scale)
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

  on_demand_instance_types = ["m6i.xlarge", "m6a.xlarge"]
  on_demand_min_size       = 3
  on_demand_max_size       = 15
  on_demand_desired_size   = 4

  spot_instance_types  = ["m6i.2xlarge", "m6a.2xlarge", "m5.2xlarge"]
  spot_min_size        = 2
  spot_max_size        = 30
  spot_desired_size    = 6

  log_retention_days = 365  # GDPR

  tags = var.common_tags
}

###############################################################################
# Aurora (EU secondary cluster - Aurora Global DB secondary)
###############################################################################

resource "aws_rds_cluster" "eu_secondary" {
  count = var.link_to_prod_us ? 1 : 0

  cluster_identifier = "${var.project_name}-${var.environment}-aurora-pg"
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_engine_version

  # Link to the Global DB cluster from prod-us
  global_cluster_identifier = var.aurora_global_cluster_id

  db_subnet_group_name   = aws_db_subnet_group.aurora_eu[0].name
  vpc_security_group_ids = [module.networking.sg_aurora_id]

  storage_encrypted = true
  kms_key_id        = var.aurora_eu_kms_key_arn  # Must be a replica key in eu-west-1

  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-aurora-final"

  deletion_protection = true

  # EU secondary is read-only by design
  enable_global_write_forwarding = var.enable_global_write_forwarding

  tags = merge(var.common_tags, {
    Name         = "${var.project_name}-${var.environment}-aurora-pg"
    Role         = "global-secondary"
    DataResidency = "EU"
  })

  lifecycle {
    ignore_changes = [master_password, master_username, global_cluster_identifier]
  }
}

resource "aws_db_subnet_group" "aurora_eu" {
  count       = var.link_to_prod_us ? 1 : 0
  name        = "${var.project_name}-${var.environment}-aurora-subnet-group"
  description = "Subnet group for Aurora EU secondary"
  subnet_ids  = module.networking.private_data_subnet_ids

  tags = var.common_tags
}

resource "aws_rds_cluster_instance" "eu_reader" {
  count = var.link_to_prod_us ? var.eu_reader_count : 0

  identifier         = "${var.project_name}-${var.environment}-aurora-eu-reader-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.eu_secondary[0].id
  instance_class     = var.aurora_instance_class
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_engine_version

  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.aurora_eu[0].name

  performance_insights_enabled = true
  performance_insights_kms_key_id = module.kms.aurora_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-aurora-eu-reader-${count.index + 1}"
    Role = "global-secondary-reader"
  })
}

###############################################################################
# ElastiCache Redis (EU - GDPR compliant, data stays in EU)
###############################################################################

module "redis" {
  source       = "../../modules/elasticache-redis"
  project_name = var.project_name
  environment  = var.environment

  engine_version     = var.redis_engine_version
  node_type          = "cache.r7g.large"
  num_shards         = 3
  replicas_per_shard = 2

  data_subnet_ids         = module.networking.private_data_subnet_ids
  redis_security_group_id = module.networking.sg_elasticache_id
  kms_key_arn             = module.kms.redis_key_arn

  snapshot_retention_limit = 7
  enable_autoscaling       = true
  autoscaling_max_shards   = 10
  log_retention_days       = 365  # GDPR

  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# MSK Kafka (EU data residency)
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

  log_retention_days = 365  # GDPR

  alarm_sns_arn = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# OpenSearch (EU - GDPR-compliant search and audit logs)
###############################################################################

module "opensearch" {
  source       = "../../modules/opensearch"
  project_name = var.project_name
  environment  = var.environment

  opensearch_version = var.opensearch_version
  instance_type      = "r6g.xlarge.search"
  instance_count     = 3

  dedicated_master_type = "r6g.large.search"
  volume_size           = 300   # More storage for GDPR audit trails
  enable_ultrawarm      = true

  data_subnet_ids              = module.networking.private_data_subnet_ids
  opensearch_security_group_id = module.networking.sg_opensearch_id
  kms_key_arn                  = module.kms.s3_key_arn
  master_user_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  service_role_arns            = [module.eks.node_group_role_arn]

  create_service_linked_role = var.create_opensearch_slr
  log_retention_days         = 365  # GDPR
  alarm_sns_arn              = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# WAF (EU - with GDPR-specific IP filtering)
###############################################################################

module "waf" {
  source       = "../../modules/waf"
  project_name = var.project_name
  environment  = var.environment

  scope                  = "REGIONAL"
  enable_shield_advanced = var.enable_shield_advanced
  alb_arn                = var.alb_arn

  log_retention_days = 365  # GDPR
  alarm_sns_arn      = module.monitoring.critical_alerts_topic_arn

  tags = var.common_tags
}

###############################################################################
# Secrets Manager (EU - GDPR data stays in EU)
###############################################################################

module "secrets" {
  source       = "../../modules/secrets-manager"
  project_name = var.project_name
  environment  = var.environment

  kms_key_arn    = module.kms.secrets_manager_key_arn
  db_host        = var.link_to_prod_us ? aws_rds_cluster.eu_secondary[0].endpoint : ""
  db_reader_host = var.link_to_prod_us ? aws_rds_cluster.eu_secondary[0].reader_endpoint : ""
  db_name        = var.db_name
  redis_configuration_endpoint = module.redis.configuration_endpoint_address

  # No cross-region replication from EU (GDPR data residency)
  replica_region = ""

  tags = var.common_tags
}

###############################################################################
# AppConfig (EU-specific feature flags)
###############################################################################

module "appconfig" {
  source       = "../../modules/appconfig"
  project_name = var.project_name
  environment  = var.environment

  alarm_arns = [module.monitoring.critical_alerts_topic_arn]

  feature_mfa_enabled                   = true
  feature_passwordless_enabled          = true
  feature_social_login_enabled          = true
  feature_fraud_detection_enabled       = true
  feature_session_binding_enabled       = true
  feature_progressive_profiling_enabled = true
  feature_account_linking_enabled       = true

  cors_allowed_origins = [
    "https://eu.${var.domain_name}",
    "https://app-eu.${var.domain_name}",
    "https://admin-eu.${var.domain_name}"
  ]

  tags = var.common_tags
}

###############################################################################
# CloudFront (EU edge distribution)
###############################################################################

module "cloudfront" {
  source       = "../../modules/cloudfront"
  project_name = var.project_name
  environment  = var.environment

  domain_name             = "eu.${var.domain_name}"
  additional_domain_names = ["app-eu.${var.domain_name}"]
  route53_zone_id         = var.route53_zone_id
  alb_dns_name            = var.alb_dns_name
  jwt_public_key_secret_arn = module.secrets.jwt_private_key_secret_arn
  s3_kms_key_arn          = module.kms.s3_key_arn
  price_class             = "PriceClass_100"   # EU + NA edge nodes

  tags = var.common_tags

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

###############################################################################
# Monitoring (EU - GDPR audit log retention)
###############################################################################

module "monitoring" {
  source       = "../../modules/monitoring"
  project_name = var.project_name
  environment  = var.environment

  alarm_email_endpoints = var.alarm_email_endpoints
  kms_key_arn           = module.kms.s3_key_arn
  eks_cluster_name      = module.eks.cluster_name
  aurora_cluster_id     = var.link_to_prod_us ? aws_rds_cluster.eu_secondary[0].id : ""
  redis_cluster_id      = module.redis.replication_group_id
  waf_acl_name          = module.waf.web_acl_name
  domain_name           = "eu.${var.domain_name}"
  log_retention_days    = 365   # GDPR requires 1 year

  tags = var.common_tags
}

###############################################################################
# GDPR-Specific: S3 Bucket for Data Subject Requests
###############################################################################

resource "aws_s3_bucket" "gdpr_dsr" {
  bucket = "${var.project_name}-${var.environment}-gdpr-dsr"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-gdpr-dsr"
    GDPRScope   = "true"
    DataClass   = "PersonalData"
    Compliance  = "GDPR-Article17"
  })
}

resource "aws_s3_bucket_public_access_block" "gdpr_dsr" {
  bucket                  = aws_s3_bucket.gdpr_dsr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "gdpr_dsr" {
  bucket = aws_s3_bucket.gdpr_dsr.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gdpr_dsr" {
  bucket = aws_s3_bucket.gdpr_dsr.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "gdpr_dsr" {
  bucket = aws_s3_bucket.gdpr_dsr.id
  rule {
    id     = "gdpr-retention"
    status = "Enabled"
    # Automatically delete data after retention period per GDPR erasure policy
    expiration {
      days = 90  # 90 days for DSR processing
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "gdpr_dsr" {
  bucket = aws_s3_bucket.gdpr_dsr.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }
}
