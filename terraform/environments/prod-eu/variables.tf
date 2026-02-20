variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_data_subnet_cidrs" { type = list(string) }
variable "kubernetes_version" { type = string; default = "1.31" }
variable "aurora_engine_version" { type = string; default = "16.2" }
variable "aurora_instance_class" { type = string; default = "db.r7g.xlarge" }
variable "eu_reader_count" { type = number; default = 2 }
variable "db_name" { type = string; default = "ciam_db" }
variable "aurora_global_cluster_id" { type = string; default = "" }
variable "aurora_eu_kms_key_arn" { type = string; default = "" }
variable "enable_global_write_forwarding" { type = bool; default = false }
variable "link_to_prod_us" { type = bool; default = false }
variable "redis_engine_version" { type = string; default = "7.1" }
variable "kafka_version" { type = string; default = "3.6.0" }
variable "opensearch_version" { type = string; default = "2.13" }
variable "create_opensearch_slr" { type = bool; default = false }
variable "domain_name" { type = string }
variable "route53_zone_id" { type = string; default = "" }
variable "alb_dns_name" { type = string; default = "" }
variable "alb_arn" { type = string; default = "" }
variable "enable_shield_advanced" { type = bool; default = false }
variable "alarm_email_endpoints" { type = list(string); default = [] }
variable "common_tags" { type = map(string); default = {} }
