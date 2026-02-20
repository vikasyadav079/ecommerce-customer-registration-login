output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  description = "WAF Web ACL name"
  value       = aws_wafv2_web_acl.main.name
}

output "web_acl_capacity" {
  description = "WAF Web ACL capacity consumed"
  value       = aws_wafv2_web_acl.main.capacity
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for WAF logs"
  value       = aws_cloudwatch_log_group.waf.arn
}

output "admin_ip_set_arn" {
  description = "Admin allowlist IP set ARN"
  value       = length(aws_wafv2_ip_set.admin_allowlist) > 0 ? aws_wafv2_ip_set.admin_allowlist[0].arn : null
}
