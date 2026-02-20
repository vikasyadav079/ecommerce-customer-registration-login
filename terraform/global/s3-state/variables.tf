variable "project_name" {
  description = "Project name - used to derive bucket and table names"
  type        = string
  default     = "ecommerce-ciam"
}

variable "aws_region" {
  description = "AWS region for state backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_change_notification_emails" {
  description = "Email addresses to notify on prod state changes"
  type        = list(string)
  default     = []
}

variable "cloudtrail_log_group" {
  description = "CloudTrail log group name for state access monitoring"
  type        = string
  default     = ""
}
