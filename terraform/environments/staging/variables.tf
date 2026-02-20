variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string; default = "us-east-1" }
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_data_subnet_cidrs" { type = list(string) }
variable "kubernetes_version" { type = string; default = "1.31" }
variable "aurora_engine_version" { type = string; default = "16.2" }
variable "db_name" { type = string; default = "ciam_db" }
variable "db_master_username" { type = string }
variable "db_master_password" { type = string; sensitive = true }
variable "redis_engine_version" { type = string; default = "7.1" }
variable "kafka_version" { type = string; default = "3.6.0" }
variable "opensearch_version" { type = string; default = "2.13" }
variable "create_opensearch_slr" { type = bool; default = false }
variable "domain_name" { type = string }
variable "route53_zone_id" { type = string; default = "" }
variable "alb_dns_name" { type = string; default = "" }
variable "alarm_email_endpoints" { type = list(string); default = [] }
variable "common_tags" { type = map(string); default = {} }
