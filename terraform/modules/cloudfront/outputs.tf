output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID (for Route53 aliases)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront"
  value       = aws_acm_certificate.cloudfront.arn
}

output "static_assets_bucket_name" {
  description = "S3 bucket name for static assets"
  value       = aws_s3_bucket.static_assets.bucket
}

output "static_assets_bucket_arn" {
  description = "S3 bucket ARN for static assets"
  value       = aws_s3_bucket.static_assets.arn
}

output "cf_logs_bucket_name" {
  description = "S3 bucket for CloudFront access logs"
  value       = aws_s3_bucket.cf_logs.bucket
}

output "lambda_edge_arn" {
  description = "Lambda@Edge function ARN (with version)"
  value       = "${aws_lambda_function.edge_jwt_validator.arn}:${aws_lambda_function.edge_jwt_validator.version}"
}
