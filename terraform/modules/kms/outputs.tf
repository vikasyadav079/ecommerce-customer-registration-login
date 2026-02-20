output "jwt_signing_key_id" {
  description = "KMS key ID for JWT signing"
  value       = aws_kms_key.jwt_signing.key_id
}

output "jwt_signing_key_arn" {
  description = "KMS key ARN for JWT signing"
  value       = aws_kms_key.jwt_signing.arn
}

output "jwt_signing_key_alias" {
  description = "KMS key alias for JWT signing"
  value       = aws_kms_alias.jwt_signing.name
}

output "aurora_key_id" {
  description = "KMS key ID for Aurora encryption"
  value       = aws_kms_key.aurora.key_id
}

output "aurora_key_arn" {
  description = "KMS key ARN for Aurora encryption"
  value       = aws_kms_key.aurora.arn
}

output "redis_key_id" {
  description = "KMS key ID for Redis encryption"
  value       = aws_kms_key.redis.key_id
}

output "redis_key_arn" {
  description = "KMS key ARN for Redis encryption"
  value       = aws_kms_key.redis.arn
}

output "s3_key_id" {
  description = "KMS key ID for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "s3_key_arn" {
  description = "KMS key ARN for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "eks_key_id" {
  description = "KMS key ID for EKS secrets encryption"
  value       = aws_kms_key.eks.key_id
}

output "eks_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}

output "secrets_manager_key_id" {
  description = "KMS key ID for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.key_id
}

output "secrets_manager_key_arn" {
  description = "KMS key ARN for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.arn
}

output "terraform_state_key_id" {
  description = "KMS key ID for Terraform state encryption"
  value       = aws_kms_key.terraform_state.key_id
}

output "terraform_state_key_arn" {
  description = "KMS key ARN for Terraform state encryption"
  value       = aws_kms_key.terraform_state.arn
}
