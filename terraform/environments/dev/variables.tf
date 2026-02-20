variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_data_subnet_cidrs" {
  type = list(string)
}

variable "developer_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "aurora_engine_version" {
  type    = string
  default = "16.2"
}

variable "db_name" {
  type    = string
  default = "ciam_db"
}

variable "db_master_username" {
  type    = string
  default = "ciam_admin"
}

variable "db_master_password" {
  type      = string
  sensitive = true
}

variable "redis_engine_version" {
  type    = string
  default = "7.1"
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "opensearch_version" {
  type    = string
  default = "2.13"
}

variable "create_opensearch_slr" {
  type    = bool
  default = true
}

variable "domain_name" {
  type = string
}

variable "alarm_email_endpoints" {
  type    = list(string)
  default = []
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
