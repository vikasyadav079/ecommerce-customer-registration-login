output "critical_alerts_topic_arn" {
  description = "SNS topic ARN for critical alerts"
  value       = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  description = "SNS topic ARN for warning alerts"
  value       = aws_sns_topic.warning_alerts.arn
}

output "overview_dashboard_name" {
  description = "CloudWatch overview dashboard name"
  value       = aws_cloudwatch_dashboard.ciam_overview.dashboard_name
}

output "security_dashboard_name" {
  description = "CloudWatch security dashboard name"
  value       = aws_cloudwatch_dashboard.ciam_security.dashboard_name
}

output "canary_api_health_name" {
  description = "Synthetics canary name for API health checks"
  value       = aws_synthetics_canary.api_health_check.name
}

output "canary_login_flow_name" {
  description = "Synthetics canary name for login flow"
  value       = aws_synthetics_canary.login_flow.name
}

output "canary_artifacts_bucket" {
  description = "S3 bucket name for canary artifacts"
  value       = aws_s3_bucket.canary_artifacts.bucket
}
