variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "alarm_arns" {
  description = "CloudWatch alarm ARNs for AppConfig deployment monitoring"
  type        = list(string)
  default     = []
}

variable "feature_mfa_enabled" {
  description = "Enable MFA feature flag"
  type        = bool
  default     = true
}

variable "feature_passwordless_enabled" {
  description = "Enable passwordless login feature flag"
  type        = bool
  default     = false
}

variable "feature_social_login_enabled" {
  description = "Enable social login feature flag"
  type        = bool
  default     = true
}

variable "feature_fraud_detection_enabled" {
  description = "Enable advanced fraud detection feature flag"
  type        = bool
  default     = false
}

variable "feature_session_binding_enabled" {
  description = "Enable session device binding feature flag"
  type        = bool
  default     = false
}

variable "feature_progressive_profiling_enabled" {
  description = "Enable progressive profiling feature flag"
  type        = bool
  default     = true
}

variable "feature_account_linking_enabled" {
  description = "Enable account linking feature flag"
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins list"
  type        = list(string)
  default     = ["https://app.example.com"]
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
