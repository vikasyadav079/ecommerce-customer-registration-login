###############################################################################
# Global Variables for ECommerce CIAM Platform
###############################################################################

variable "aws_region" {
  description = "Primary AWS region for resource deployment"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(east|west|north|south|central|northeast|southeast|northwest|southwest)-[1-9]$", var.aws_region))
    error_message = "Must be a valid AWS region identifier."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod-us, prod-eu)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod-us", "prod-eu"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod-us, prod-eu."
  }
}

variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "ecommerce-ciam"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,28}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 4-30 lowercase alphanumeric characters and hyphens."
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

###############################################################################
# Networking Variables
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use (minimum 3 for production)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway to reduce cost (not recommended for production)"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic monitoring"
  type        = bool
  default     = true
}

###############################################################################
# EKS Variables
###############################################################################

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_cluster_endpoint_public_access" {
  description = "Enable public access to EKS cluster API endpoint"
  type        = bool
  default     = false
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access public EKS endpoint"
  type        = list(string)
  default     = []
}

variable "on_demand_instance_types" {
  description = "EC2 instance types for on-demand node group"
  type        = list(string)
  default     = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
}

variable "spot_instance_types" {
  description = "EC2 instance types for spot node group"
  type        = list(string)
  default     = ["m6i.2xlarge", "m6a.2xlarge", "m5.2xlarge", "m5d.2xlarge", "m5n.2xlarge"]
}

variable "on_demand_min_size" {
  description = "Minimum number of on-demand nodes"
  type        = number
  default     = 2
}

variable "on_demand_max_size" {
  description = "Maximum number of on-demand nodes"
  type        = number
  default     = 10
}

variable "on_demand_desired_size" {
  description = "Desired number of on-demand nodes"
  type        = number
  default     = 3
}

variable "spot_min_size" {
  description = "Minimum number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum number of spot nodes"
  type        = number
  default     = 20
}

variable "spot_desired_size" {
  description = "Desired number of spot nodes"
  type        = number
  default     = 3
}

###############################################################################
# Aurora PostgreSQL Variables
###############################################################################

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.2"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora cluster instances"
  type        = string
  default     = "db.r7g.xlarge"
}

variable "aurora_reader_count" {
  description = "Number of Aurora reader instances"
  type        = number
  default     = 2
}

variable "aurora_backup_retention_days" {
  description = "Number of days to retain Aurora automated backups"
  type        = number
  default     = 35

  validation {
    condition     = var.aurora_backup_retention_days >= 1 && var.aurora_backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection for Aurora cluster"
  type        = bool
  default     = true
}

variable "enable_aurora_global_db" {
  description = "Enable Aurora Global Database for cross-region replication"
  type        = bool
  default     = false
}

###############################################################################
# ElastiCache Redis Variables
###############################################################################

variable "redis_node_type" {
  description = "ElastiCache node type for Redis cluster"
  type        = string
  default     = "cache.r7g.large"
}

variable "redis_num_shards" {
  description = "Number of shards in Redis cluster mode"
  type        = number
  default     = 3
}

variable "redis_replicas_per_shard" {
  description = "Number of replicas per Redis shard"
  type        = number
  default     = 2
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots"
  type        = number
  default     = 7
}

###############################################################################
# MSK Kafka Variables
###############################################################################

variable "kafka_version" {
  description = "Apache Kafka version for MSK cluster"
  type        = string
  default     = "3.6.0"
}

variable "kafka_broker_instance_type" {
  description = "EC2 instance type for MSK Kafka brokers"
  type        = string
  default     = "kafka.m5.xlarge"
}

variable "kafka_brokers_per_az" {
  description = "Number of Kafka brokers per availability zone"
  type        = number
  default     = 1
}

variable "kafka_broker_volume_size" {
  description = "EBS volume size in GB for each Kafka broker"
  type        = number
  default     = 500
}

###############################################################################
# OpenSearch Variables
###############################################################################

variable "opensearch_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "2.13"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  default     = "r6g.xlarge.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  default     = 3
}

variable "opensearch_dedicated_master_type" {
  description = "Instance type for OpenSearch dedicated master nodes"
  type        = string
  default     = "r6g.large.search"
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GB for OpenSearch nodes"
  type        = number
  default     = 200
}

###############################################################################
# Domain and Certificate Variables
###############################################################################

variable "domain_name" {
  description = "Primary domain name for the CIAM platform"
  type        = string
  default     = "ecommerce-ciam.example.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS management"
  type        = string
  default     = ""
}

###############################################################################
# Monitoring Variables
###############################################################################

variable "alarm_email_endpoints" {
  description = "Email addresses for CloudWatch alarm notifications"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications (stored in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring for RDS/Aurora instances"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 90
}

###############################################################################
# Feature Flags
###############################################################################

variable "enable_waf_shield_advanced" {
  description = "Enable AWS Shield Advanced for DDoS protection (billed separately)"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub for compliance standards"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for compliance recording"
  type        = bool
  default     = true
}
