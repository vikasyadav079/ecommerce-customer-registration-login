variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ecommerce-ciam"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL (with https://)"
  type        = string
}

variable "irsa_service_accounts" {
  description = "Map of service name to namespace+sa_name for IRSA"
  type = map(object({
    namespace = string
    sa_name   = string
  }))
  default = {}
}

variable "jwt_signing_key_arn" {
  description = "KMS key ARN for JWT signing"
  type        = string
  default     = ""
}

variable "appconfig_app_id" {
  description = "AWS AppConfig application ID"
  type        = string
  default     = "*"
}

variable "github_actions_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "your-github-org"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "ecommerce-ciam"
}

variable "create_github_oidc_provider" {
  description = "Create GitHub Actions OIDC provider (once per account)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
