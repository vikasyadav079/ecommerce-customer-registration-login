output "domain_id" {
  description = "OpenSearch domain ID"
  value       = aws_opensearch_domain.main.domain_id
}

output "domain_name" {
  description = "OpenSearch domain name"
  value       = aws_opensearch_domain.main.domain_name
}

output "domain_arn" {
  description = "OpenSearch domain ARN"
  value       = aws_opensearch_domain.main.arn
}

output "domain_endpoint" {
  description = "OpenSearch domain HTTPS endpoint"
  value       = aws_opensearch_domain.main.endpoint
}

output "kibana_endpoint" {
  description = "OpenSearch Dashboards (Kibana) endpoint"
  value       = aws_opensearch_domain.main.kibana_endpoint
}

output "index_config_ssm_parameter" {
  description = "SSM parameter name with index configuration"
  value       = aws_ssm_parameter.opensearch_index_config.name
}
