output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.primary.id
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.primary.arn
}

output "cluster_endpoint" {
  description = "Aurora writer endpoint"
  value       = aws_rds_cluster.primary.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = aws_rds_cluster.primary.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.primary.port
}

output "cluster_database_name" {
  description = "Aurora database name"
  value       = aws_rds_cluster.primary.database_name
}

output "cluster_master_username" {
  description = "Aurora master username"
  value       = aws_rds_cluster.primary.master_username
  sensitive   = true
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID"
  value       = aws_rds_cluster.primary.cluster_resource_id
}

output "global_cluster_id" {
  description = "Aurora global cluster ID"
  value       = var.enable_global_db ? aws_rds_global_cluster.main[0].id : null
}

output "credentials_secret_arn" {
  description = "Secrets Manager ARN for Aurora credentials"
  value       = aws_secretsmanager_secret.aurora_creds.arn
}

output "writer_instance_id" {
  description = "Aurora writer instance identifier"
  value       = aws_rds_cluster_instance.writer.id
}

output "reader_instance_ids" {
  description = "Aurora reader instance identifiers"
  value       = aws_rds_cluster_instance.readers[*].id
}

output "subnet_group_name" {
  description = "Aurora DB subnet group name"
  value       = aws_db_subnet_group.aurora.name
}
