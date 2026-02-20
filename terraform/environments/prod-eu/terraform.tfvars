###############################################################################
# PROD-EU Environment - terraform.tfvars (eu-west-1, GDPR Data Residency)
###############################################################################

project_name = "ecommerce-ciam"
environment  = "prod-eu"

###############################################################################
# Networking (eu-west-1)
###############################################################################

vpc_cidr = "10.1.0.0/16"

availability_zones = [
  "eu-west-1a",
  "eu-west-1b",
  "eu-west-1c"
]

public_subnet_cidrs = [
  "10.1.1.0/24",
  "10.1.2.0/24",
  "10.1.3.0/24"
]

private_app_subnet_cidrs = [
  "10.1.11.0/24",
  "10.1.12.0/24",
  "10.1.13.0/24"
]

private_data_subnet_cidrs = [
  "10.1.21.0/24",
  "10.1.22.0/24",
  "10.1.23.0/24"
]

###############################################################################
# Kubernetes
###############################################################################

kubernetes_version = "1.31"

###############################################################################
# Aurora Global DB
###############################################################################

aurora_engine_version    = "16.2"
aurora_instance_class    = "db.r7g.xlarge"
eu_reader_count          = 2
db_name                  = "ciam_db"

# Aurora Global Cluster ID from prod-us (populate after prod-us apply)
aurora_global_cluster_id = ""   # e.g. "ecommerce-ciam-prod-us-aurora-pg-global"

# KMS replica key in eu-west-1 (must be created as replica of prod-us aurora key)
aurora_eu_kms_key_arn    = ""   # e.g. "arn:aws:kms:eu-west-1:123456789:key/..."

# Enable write forwarding to primary (for writes from EU edge)
enable_global_write_forwarding = false

# Link to prod-us remote state
link_to_prod_us = true

###############################################################################
# Redis
###############################################################################

redis_engine_version = "7.1"

###############################################################################
# Kafka
###############################################################################

kafka_version = "3.6.0"

###############################################################################
# OpenSearch
###############################################################################

opensearch_version    = "2.13"
create_opensearch_slr = false   # Created by prod-us (if same account) or first time

###############################################################################
# Domain & DNS
###############################################################################

domain_name     = "ecommerce-ciam.example.com"
route53_zone_id = "Z0123456789ABCDEFGHIJ"  # Replace with actual zone ID

###############################################################################
# Load Balancer
###############################################################################

alb_dns_name = ""   # Set after EU ALB provisioning
alb_arn      = ""   # Set after EU ALB provisioning

###############################################################################
# Shield Advanced
###############################################################################

enable_shield_advanced = false

###############################################################################
# Monitoring & Alerting
###############################################################################

alarm_email_endpoints = [
  "prod-eu-alerts@example.com",
  "eu-on-call@example.com",
  "sre-eu@example.com",
  "dpo@example.com"   # Data Protection Officer for GDPR incidents
]

###############################################################################
# Common Tags (GDPR-enriched)
###############################################################################

common_tags = {
  Environment   = "prod-eu"
  Project       = "ecommerce-ciam"
  Team          = "Platform-Engineering"
  CostCenter    = "CIAM-PROD-EU"
  Terraform     = "true"
  DataResidency = "EU"
  GDPRScope     = "true"
  Compliance    = "GDPR,SOC2"
  DataClass     = "PersonalData"
  Region        = "eu-west-1"
  BackupPolicy  = "daily-35d"
  DPO           = "dpo@example.com"
}
