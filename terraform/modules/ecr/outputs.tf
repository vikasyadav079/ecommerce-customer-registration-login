output "repository_urls" {
  description = "Map of microservice name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of microservice name to ECR repository ARN"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.arn }
}

output "repository_names" {
  description = "Map of microservice name to ECR repository name"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.name }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "registry_url" {
  description = "ECR registry URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}
