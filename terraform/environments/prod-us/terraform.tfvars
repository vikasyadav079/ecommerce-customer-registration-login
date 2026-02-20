###############################################################################
# PROD-US Environment - terraform.tfvars (us-east-1)
###############################################################################

project_name = "ecommerce-ciam"
environment  = "prod-us"
aws_region   = "us-east-1"

###############################################################################
# Networking
###############################################################################

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

private_app_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24",
  "10.0.13.0/24"
]

private_data_subnet_cidrs = [
  "10.0.21.0/24",
  "10.0.22.0/24",
  "10.0.23.0/24"
]

###############################################################################
# Kubernetes
###############################################################################

kubernetes_version = "1.31"

###############################################################################
# Aurora
###############################################################################

aurora_engine_version = "16.2"
db_name               = "ciam_db"
db_master_username    = "ciam_admin"
# db_master_password - set via TF_VAR_db_master_password or Vault

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

opensearch_version = "2.13"

###############################################################################
# Domain & DNS
###############################################################################

domain_name     = "ecommerce-ciam.example.com"
route53_zone_id = "Z0123456789ABCDEFGHIJ"  # Replace with actual hosted zone ID

###############################################################################
# Load Balancer (populated after initial apply or from remote state)
###############################################################################

alb_dns_name = ""   # Set after ALB provisioning
alb_arn      = ""   # Set after ALB provisioning

###############################################################################
# Cross-region / Cross-account
###############################################################################

prod_eu_account_id    = ""   # Set if prod-eu is in a separate AWS account
eu_replica_kms_key_arn = ""  # KMS key ARN in eu-west-1

###############################################################################
# Shield Advanced (billed at ~$3000/month)
###############################################################################

enable_shield_advanced = false  # Enable when DDoS protection required

###############################################################################
# Secret Rotation Lambda
###############################################################################

secrets_rotation_lambda_arn = ""  # ARN of Secrets Manager rotation Lambda

###############################################################################
# Monitoring - Synthetic Canaries
###############################################################################

canary_test_username = "canary-prod@example.com"
# canary_test_password - set via TF_VAR_canary_test_password

alarm_email_endpoints = [
  "prod-alerts@example.com",
  "on-call@example.com",
  "sre-team@example.com"
]

###############################################################################
# Common Tags
###############################################################################

common_tags = {
  Environment  = "prod-us"
  Project      = "ecommerce-ciam"
  Team         = "Platform-Engineering"
  CostCenter   = "CIAM-PROD-US"
  Terraform    = "true"
  Compliance   = "SOC2,PCI-DSS,GDPR"
  DataClass    = "Confidential"
  Region       = "us-east-1"
  BackupPolicy = "daily-35d"
}
