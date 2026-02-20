output "jwt_private_key_secret_arn" {
  description = "Secrets Manager ARN for JWT private key"
  value       = aws_secretsmanager_secret.jwt_private_key.arn
}

output "jwt_previous_key_secret_arn" {
  description = "Secrets Manager ARN for JWT previous key"
  value       = aws_secretsmanager_secret.jwt_previous_key.arn
}

output "db_ciam_service_secret_arn" {
  description = "Secrets Manager ARN for CIAM service DB credentials"
  value       = aws_secretsmanager_secret.db_ciam_service.arn
}

output "db_readonly_secret_arn" {
  description = "Secrets Manager ARN for read-only DB credentials"
  value       = aws_secretsmanager_secret.db_readonly.arn
}

output "redis_auth_secret_arn" {
  description = "Secrets Manager ARN for Redis auth token"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "oauth2_client_secrets_arn" {
  description = "Secrets Manager ARN for OAuth2 client secrets"
  value       = aws_secretsmanager_secret.oauth2_client_secrets.arn
}

output "smtp_credentials_secret_arn" {
  description = "Secrets Manager ARN for SMTP credentials"
  value       = aws_secretsmanager_secret.smtp_credentials.arn
}

output "twilio_credentials_secret_arn" {
  description = "Secrets Manager ARN for Twilio credentials"
  value       = aws_secretsmanager_secret.twilio_credentials.arn
}

output "app_encryption_keys_secret_arn" {
  description = "Secrets Manager ARN for application encryption keys"
  value       = aws_secretsmanager_secret.app_encryption_keys.arn
}

output "all_secret_arns" {
  description = "Map of all secret names to ARNs"
  value = {
    jwt_private_key       = aws_secretsmanager_secret.jwt_private_key.arn
    jwt_previous_key      = aws_secretsmanager_secret.jwt_previous_key.arn
    db_ciam_service       = aws_secretsmanager_secret.db_ciam_service.arn
    db_readonly           = aws_secretsmanager_secret.db_readonly.arn
    redis_auth            = aws_secretsmanager_secret.redis_auth.arn
    oauth2_clients        = aws_secretsmanager_secret.oauth2_client_secrets.arn
    smtp                  = aws_secretsmanager_secret.smtp_credentials.arn
    twilio                = aws_secretsmanager_secret.twilio_credentials.arn
    app_encryption_keys   = aws_secretsmanager_secret.app_encryption_keys.arn
  }
}
