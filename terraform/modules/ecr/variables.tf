variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for ECR encryption"
  type        = string
}

variable "image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "Allow repository deletion even if it contains images"
  type        = bool
  default     = false
}

variable "enable_cross_account_access" {
  description = "Enable cross-account ECR pull access"
  type        = bool
  default     = false
}

variable "cross_account_pull_arns" {
  description = "IAM ARNs allowed to pull from ECR"
  type        = list(string)
  default     = []
}

variable "enable_enhanced_scanning" {
  description = "Enable ECR Enhanced Scanning (Inspector)"
  type        = bool
  default     = true
}

variable "enable_quay_pull_through" {
  description = "Enable pull-through cache for Quay.io"
  type        = bool
  default     = false
}

variable "quay_credential_arn" {
  description = "Secrets Manager ARN for Quay.io credentials"
  type        = string
  default     = ""
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for scan finding alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
