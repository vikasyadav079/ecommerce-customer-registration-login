variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "num_shards" {
  description = "Number of shards (node groups)"
  type        = number
  default     = 3
}

variable "replicas_per_shard" {
  description = "Number of replicas per shard"
  type        = number
  default     = 2
}

variable "data_subnet_ids" {
  description = "Subnet IDs for ElastiCache"
  type        = list(string)
}

variable "redis_security_group_id" {
  description = "Security group ID for Redis"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for Redis encryption"
  type        = string
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "enable_autoscaling" {
  description = "Enable auto-scaling for Redis shards"
  type        = bool
  default     = true
}

variable "autoscaling_max_shards" {
  description = "Maximum number of shards for auto-scaling"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
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
