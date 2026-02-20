variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for Secrets Manager encryption"
  type        = string
}

variable "replica_region" {
  description = "Secondary region for secret replication"
  type        = string
  default     = "eu-west-1"
}

variable "replica_kms_key_arn" {
  description = "KMS key ARN in replica region"
  type        = string
  default     = ""
}

variable "jwt_private_key_pem" {
  description = "RSA private key PEM for JWT signing"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_GENERATED_KEY"
}

variable "jwt_public_key_pem" {
  description = "RSA public key PEM for JWT verification"
  type        = string
  default     = "REPLACE_WITH_GENERATED_KEY"
}

variable "db_host" {
  description = "Aurora writer endpoint"
  type        = string
  default     = ""
}

variable "db_reader_host" {
  description = "Aurora reader endpoint"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ciam_db"
}

variable "db_ciam_service_password" {
  description = "Password for ciam_service DB user"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_STRONG_PASSWORD"
}

variable "db_readonly_password" {
  description = "Password for ciam_readonly DB user"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_STRONG_PASSWORD"
}

variable "redis_auth_token" {
  description = "Redis authentication token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "redis_configuration_endpoint" {
  description = "Redis cluster configuration endpoint"
  type        = string
  default     = ""
}

variable "oauth2_admin_client_secret" {
  description = "OAuth2 admin portal client secret"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_STRONG_SECRET"
}

variable "oauth2_mobile_client_secret" {
  description = "OAuth2 mobile app client secret"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_STRONG_SECRET"
}

variable "oauth2_web_client_secret" {
  description = "OAuth2 web app client secret"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_STRONG_SECRET"
}

variable "smtp_host" {
  description = "SMTP server hostname"
  type        = string
  default     = "email-smtp.us-east-1.amazonaws.com"
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = number
  default     = 587
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_from_address" {
  description = "From email address"
  type        = string
  default     = "noreply@example.com"
}

variable "twilio_account_sid" {
  description = "Twilio account SID"
  type        = string
  default     = ""
}

variable "twilio_auth_token" {
  description = "Twilio auth token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twilio_from_number" {
  description = "Twilio sender phone number"
  type        = string
  default     = ""
}

variable "twilio_verify_service_sid" {
  description = "Twilio Verify service SID for MFA"
  type        = string
  default     = ""
}

variable "rotation_lambda_arn" {
  description = "Lambda ARN for automatic secret rotation"
  type        = string
  default     = ""
}

variable "token_service_role_arn" {
  description = "IAM role ARN for token service (IRSA)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
