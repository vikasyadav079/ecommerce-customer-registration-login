variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
}

variable "additional_domain_names" {
  description = "Additional domain names for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name as origin for API traffic"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN (must be in us-east-1 for CloudFront)"
  type        = string
  default     = ""
}

variable "jwt_public_key_secret_arn" {
  description = "Secrets Manager ARN for JWT public key (used by Lambda@Edge)"
  type        = string
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 bucket encryption"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_All"
}

variable "blocked_countries" {
  description = "Country codes to geo-block"
  type        = list(string)
  default     = []
}

variable "cloudfront_secret_header" {
  description = "Secret value for X-CloudFront-Secret header (ALB validation)"
  type        = string
  sensitive   = true
  default     = "REPLACE_WITH_RANDOM_SECRET"
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
