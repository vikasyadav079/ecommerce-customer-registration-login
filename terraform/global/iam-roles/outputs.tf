output "auth_service_role_arn" {
  description = "IAM role ARN for auth service"
  value       = aws_iam_role.auth_service.arn
}

output "token_service_role_arn" {
  description = "IAM role ARN for token service"
  value       = aws_iam_role.token_service.arn
}

output "user_service_role_arn" {
  description = "IAM role ARN for user service"
  value       = aws_iam_role.user_service.arn
}

output "notification_service_role_arn" {
  description = "IAM role ARN for notification service"
  value       = aws_iam_role.notification_service.arn
}

output "audit_service_role_arn" {
  description = "IAM role ARN for audit service"
  value       = aws_iam_role.audit_service.arn
}

output "risk_engine_role_arn" {
  description = "IAM role ARN for risk engine"
  value       = aws_iam_role.risk_engine.arn
}

output "api_gateway_role_arn" {
  description = "IAM role ARN for API gateway"
  value       = aws_iam_role.api_gateway.arn
}

output "cicd_deploy_role_arn" {
  description = "IAM role ARN for CI/CD deployments"
  value       = aws_iam_role.cicd_deploy.arn
}

output "github_actions_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : var.github_actions_oidc_provider_arn
}

output "all_service_role_arns" {
  description = "Map of all service role ARNs"
  value = {
    auth_service         = aws_iam_role.auth_service.arn
    token_service        = aws_iam_role.token_service.arn
    user_service         = aws_iam_role.user_service.arn
    notification_service = aws_iam_role.notification_service.arn
    audit_service        = aws_iam_role.audit_service.arn
    risk_engine          = aws_iam_role.risk_engine.arn
    api_gateway          = aws_iam_role.api_gateway.arn
    cicd_deploy          = aws_iam_role.cicd_deploy.arn
  }
}
