output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of OIDC provider (without https://)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "node_group_role_arn" {
  description = "IAM role ARN for node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_group_role_name" {
  description = "IAM role name for node groups"
  value       = aws_iam_role.node_group.name
}

output "karpenter_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = aws_iam_role.karpenter_controller.arn
}

output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN"
  value       = aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster autoscaler IAM role ARN"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "karpenter_interruption_queue_url" {
  description = "SQS queue URL for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "karpenter_interruption_queue_arn" {
  description = "SQS queue ARN for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}

output "on_demand_node_group_arn" {
  description = "ARN of on-demand node group"
  value       = aws_eks_node_group.on_demand.arn
}

output "spot_node_group_arn" {
  description = "ARN of spot node group"
  value       = aws_eks_node_group.spot.arn
}
