variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EKS control plane"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed for public endpoint access"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
}

variable "on_demand_instance_types" {
  description = "Instance types for on-demand node group"
  type        = list(string)
  default     = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
}

variable "spot_instance_types" {
  description = "Instance types for spot node group"
  type        = list(string)
  default     = ["m6i.2xlarge", "m6a.2xlarge", "m5.2xlarge", "m5d.2xlarge"]
}

variable "on_demand_min_size" {
  description = "Minimum on-demand nodes"
  type        = number
  default     = 2
}

variable "on_demand_max_size" {
  description = "Maximum on-demand nodes"
  type        = number
  default     = 10
}

variable "on_demand_desired_size" {
  description = "Desired on-demand nodes"
  type        = number
  default     = 3
}

variable "spot_min_size" {
  description = "Minimum spot nodes"
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum spot nodes"
  type        = number
  default     = 20
}

variable "spot_desired_size" {
  description = "Desired spot nodes"
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
