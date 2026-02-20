variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "enable_multi_region_keys" {
  description = "Create multi-region primary keys (for global replication)"
  type        = bool
  default     = false
}

variable "jwt_signer_role_arns" {
  description = "IAM role ARNs allowed to use JWT signing key"
  type        = list(string)
  default     = []
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for KMS alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
