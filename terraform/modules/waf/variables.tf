variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "scope" {
  description = "WAF scope: REGIONAL (ALB/API GW) or CLOUDFRONT"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "blocked_countries" {
  description = "ISO 3166-1 alpha-2 country codes to block"
  type        = list(string)
  default     = []
}

variable "admin_allowed_ips" {
  description = "IPv4 CIDR blocks allowed for admin access"
  type        = list(string)
  default     = []
}

variable "enable_shield_advanced" {
  description = "Enable AWS Shield Advanced protection"
  type        = bool
  default     = false
}

variable "alb_arn" {
  description = "ALB ARN for Shield Advanced protection"
  type        = string
  default     = ""
}

variable "cloudfront_arn" {
  description = "CloudFront distribution ARN for Shield Advanced"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "KMS key ARN for WAF log encryption"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for WAF alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
