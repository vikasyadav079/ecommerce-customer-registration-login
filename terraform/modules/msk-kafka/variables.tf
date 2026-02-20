variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka version"
  type        = string
  default     = "3.6.0"
}

variable "broker_instance_type" {
  description = "EC2 instance type for Kafka brokers"
  type        = string
  default     = "kafka.m5.xlarge"
}

variable "brokers_per_az" {
  description = "Number of brokers per availability zone"
  type        = number
  default     = 1
}

variable "broker_volume_size" {
  description = "EBS volume size in GB for each broker"
  type        = number
  default     = 500
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "data_subnet_ids" {
  description = "Subnet IDs for MSK brokers"
  type        = list(string)
}

variable "msk_security_group_id" {
  description = "Security group ID for MSK"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for MSK encryption"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 30
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
