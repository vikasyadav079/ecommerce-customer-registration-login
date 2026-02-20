variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "opensearch_version" {
  description = "OpenSearch version"
  type        = string
  default     = "2.13"
}

variable "instance_type" {
  description = "OpenSearch data node instance type"
  type        = string
  default     = "r6g.xlarge.search"
}

variable "instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  default     = 3
}

variable "dedicated_master_type" {
  description = "OpenSearch dedicated master node type"
  type        = string
  default     = "r6g.large.search"
}

variable "volume_size" {
  description = "EBS volume size in GB for OpenSearch nodes"
  type        = number
  default     = 200
}

variable "enable_ultrawarm" {
  description = "Enable UltraWarm storage tier"
  type        = bool
  default     = false
}

variable "data_subnet_ids" {
  description = "Subnet IDs for OpenSearch domain"
  type        = list(string)
}

variable "opensearch_security_group_id" {
  description = "Security group ID for OpenSearch"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for OpenSearch encryption"
  type        = string
}

variable "master_user_arn" {
  description = "IAM ARN for OpenSearch master user"
  type        = string
}

variable "service_role_arns" {
  description = "IAM ARNs of service roles that need OpenSearch access"
  type        = list(string)
  default     = []
}

variable "create_service_linked_role" {
  description = "Create the OpenSearch service-linked role"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alarm_sns_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
