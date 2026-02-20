output "application_id" {
  description = "AppConfig application ID"
  value       = aws_appconfig_application.ciam.id
}

output "application_name" {
  description = "AppConfig application name"
  value       = aws_appconfig_application.ciam.name
}

output "environment_id" {
  description = "AppConfig environment ID"
  value       = aws_appconfig_environment.main.environment_id
}

output "feature_flags_profile_id" {
  description = "AppConfig feature flags configuration profile ID"
  value       = aws_appconfig_configuration_profile.feature_flags.configuration_profile_id
}

output "service_config_profile_id" {
  description = "AppConfig service configuration profile ID"
  value       = aws_appconfig_configuration_profile.service_config.configuration_profile_id
}

output "linear_deployment_strategy_id" {
  description = "AppConfig linear deployment strategy ID"
  value       = aws_appconfig_deployment_strategy.linear_10_percent.id
}

output "canary_deployment_strategy_id" {
  description = "AppConfig canary deployment strategy ID"
  value       = aws_appconfig_deployment_strategy.canary_10_percent.id
}
