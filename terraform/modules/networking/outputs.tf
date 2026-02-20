output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets"
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "sg_eks_cluster_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "sg_eks_nodes_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_nodes.id
}

output "sg_aurora_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "sg_elasticache_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.elasticache.id
}

output "sg_msk_id" {
  description = "Security group ID for MSK"
  value       = aws_security_group.msk.id
}

output "sg_opensearch_id" {
  description = "Security group ID for OpenSearch"
  value       = aws_security_group.opensearch.id
}

output "sg_alb_public_id" {
  description = "Security group ID for public ALB"
  value       = aws_security_group.alb_public.id
}

output "sg_bastion_id" {
  description = "Security group ID for bastion"
  value       = aws_security_group.bastion.id
}

output "private_route_table_ids" {
  description = "IDs of private app route tables"
  value       = aws_route_table.private_app[*].id
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "vpc_flow_log_group_arn" {
  description = "ARN of CloudWatch log group for VPC flow logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].arn : null
}
