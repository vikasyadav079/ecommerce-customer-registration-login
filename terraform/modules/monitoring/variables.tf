variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "alarm_email_endpoints" {
  description = "Email addresses for alarm notifications"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for SNS and log encryption"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "EKS cluster name for monitoring"
  type        = string
  default     = ""
}

variable "aurora_cluster_id" {
  description = "Aurora cluster identifier for monitoring"
  type        = string
  default     = ""
}

variable "redis_cluster_id" {
  description = "Redis replication group ID for monitoring"
  type        = string
  default     = ""
}

variable "waf_acl_name" {
  description = "WAF Web ACL name for monitoring"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Platform domain name for canaries"
  type        = string
  default     = ""
}

variable "canary_test_username" {
  description = "Test user for canary login flow"
  type        = string
  default     = "canary-test@example.com"
}

variable "canary_test_password" {
  description = "Test user password for canary login flow"
  type        = string
  sensitive   = true
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
