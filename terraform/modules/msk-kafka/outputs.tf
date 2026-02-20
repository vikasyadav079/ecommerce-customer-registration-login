output "cluster_arn" {
  description = "MSK cluster ARN"
  value       = aws_msk_cluster.main.arn
}

output "cluster_name" {
  description = "MSK cluster name"
  value       = aws_msk_cluster.main.cluster_name
}

output "bootstrap_brokers_sasl_iam" {
  description = "Kafka bootstrap brokers (SASL/IAM)"
  value       = aws_msk_cluster.main.bootstrap_brokers_sasl_iam
  sensitive   = true
}

output "bootstrap_brokers_tls" {
  description = "Kafka bootstrap brokers (TLS)"
  value       = aws_msk_cluster.main.bootstrap_brokers_tls
  sensitive   = true
}

output "zookeeper_connect_string" {
  description = "ZooKeeper connection string"
  value       = aws_msk_cluster.main.zookeeper_connect_string
  sensitive   = true
}

output "current_version" {
  description = "Current MSK cluster version"
  value       = aws_msk_cluster.main.current_version
}

output "credentials_secret_arn" {
  description = "Secrets Manager ARN for MSK credentials"
  value       = aws_secretsmanager_secret.msk_credentials.arn
}

output "kafka_admin_role_arn" {
  description = "IAM role ARN for Kafka admin operations"
  value       = aws_iam_role.kafka_admin.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for MSK"
  value       = aws_cloudwatch_log_group.msk.name
}

output "topics_ssm_parameter" {
  description = "SSM parameter name with Kafka topic definitions"
  value       = aws_ssm_parameter.kafka_topics.name
}
