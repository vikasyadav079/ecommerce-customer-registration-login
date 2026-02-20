variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.2"
}

variable "instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r7g.xlarge"
}

variable "reader_count" {
  description = "Number of reader instances"
  type        = number
  default     = 2
}

variable "database_name" {
  description = "Name of the initial database"
  type        = string
  default     = "ciam_db"
}

variable "master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "ciam_admin"
}

variable "master_password" {
  description = "Master password for Aurora"
  type        = string
  sensitive   = true
}

variable "data_subnet_ids" {
  description = "Subnet IDs for Aurora (data tier)"
  type        = list(string)
}

variable "aurora_security_group_id" {
  description = "Security group ID for Aurora"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for Aurora encryption"
  type        = string
}

variable "backup_retention_days" {
  description = "Days to retain automated backups"
  type        = number
  default     = 35
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "enable_global_db" {
  description = "Enable Aurora Global Database"
  type        = bool
  default     = false
}

variable "enable_enhanced_monitoring" {
  description = "Enable RDS Enhanced Monitoring"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable read replica autoscaling"
  type        = bool
  default     = true
}

variable "autoscaling_max_replicas" {
  description = "Max read replicas for autoscaling"
  type        = number
  default     = 5
}

variable "serverless_min_capacity" {
  description = "Aurora Serverless v2 minimum capacity (ACUs)"
  type        = number
  default     = 0.5
}

variable "serverless_max_capacity" {
  description = "Aurora Serverless v2 maximum capacity (ACUs)"
  type        = number
  default     = 64
}

variable "rotation_lambda_arn" {
  description = "Lambda ARN for secrets rotation"
  type        = string
  default     = ""
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
