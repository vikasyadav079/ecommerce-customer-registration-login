output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "state_lock_table_arn" {
  description = "DynamoDB table ARN for state locking"
  value       = aws_dynamodb_table.terraform_state_lock.arn
}

output "kms_key_id" {
  description = "KMS key ID for state encryption"
  value       = aws_kms_key.terraform_state.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "kms_key_alias" {
  description = "KMS key alias for state encryption"
  value       = aws_kms_alias.terraform_state.name
}

output "terraform_state_access_policy_arn" {
  description = "IAM policy ARN for Terraform state access"
  value       = aws_iam_policy.terraform_state_access.arn
}

output "state_logs_bucket_name" {
  description = "S3 bucket name for state access logs"
  value       = aws_s3_bucket.terraform_state_logs.bucket
}

output "backend_config" {
  description = "Backend configuration to paste into Terraform backend blocks"
  value = <<-EOT
    # Use this configuration in your terraform backend blocks:
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.bucket}"
      region         = "${data.aws_region.current.name}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
      kms_key_id     = "${aws_kms_alias.terraform_state.name}"
    }
  EOT
}
