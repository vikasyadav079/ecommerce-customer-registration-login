###############################################################################
# CloudFront Distribution - Lambda@Edge, ACM Certificate, WAF
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  domain_name = var.domain_name
}

data "aws_caller_identity" "current" {}

###############################################################################
# ACM Certificate (must be in us-east-1 for CloudFront)
###############################################################################

resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = concat(
    ["*.${var.domain_name}"],
    var.additional_domain_names
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cloudfront-cert"
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

###############################################################################
# Lambda@Edge - JWT Validation at Edge
###############################################################################

resource "aws_iam_role" "lambda_edge" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  provider   = aws.us_east_1
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_edge_secrets" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-lambda-edge-secrets"
  role     = aws_iam_role.lambda_edge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.jwt_public_key_secret_arn
      }
    ]
  })
}

# Lambda@Edge for JWT validation on viewer request
data "archive_file" "lambda_edge_jwt" {
  type        = "zip"
  output_path = "/tmp/lambda-edge-jwt.zip"

  source {
    filename = "index.js"
    content  = <<-EOT
      'use strict';

      const jwt = require('jsonwebtoken');
      const AWS = require('aws-sdk');

      let publicKey = null;
      const EXCLUDED_PATHS = [
        '/api/v1/auth/login',
        '/api/v1/auth/register',
        '/api/v1/auth/token',
        '/api/v1/auth/password-reset',
        '/api/v1/auth/refresh',
        '/health',
        '/.well-known/openid-configuration',
        '/.well-known/jwks.json'
      ];

      async function getPublicKey() {
        if (publicKey) return publicKey;
        const sm = new AWS.SecretsManager({ region: 'us-east-1' });
        const secret = await sm.getSecretValue({
          SecretId: process.env.JWT_PUBLIC_KEY_SECRET_ARN
        }).promise();
        const parsed = JSON.parse(secret.SecretString);
        publicKey = parsed.public_key;
        return publicKey;
      }

      exports.handler = async (event) => {
        const request = event.Records[0].cf.request;
        const headers = request.headers;
        const uri = request.uri;

        // Skip authentication for public endpoints
        if (EXCLUDED_PATHS.some(p => uri.startsWith(p))) {
          return request;
        }

        // Skip if no Authorization header
        const authHeader = headers.authorization && headers.authorization[0]
          ? headers.authorization[0].value
          : null;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
          return {
            status: '401',
            statusDescription: 'Unauthorized',
            headers: {
              'content-type': [{ key: 'Content-Type', value: 'application/json' }],
              'www-authenticate': [{ key: 'WWW-Authenticate', value: 'Bearer realm="ciam"' }]
            },
            body: JSON.stringify({ error: 'Unauthorized', code: 'MISSING_TOKEN' })
          };
        }

        const token = authHeader.substring(7);

        try {
          const key = await getPublicKey();
          const decoded = jwt.verify(token, key, { algorithms: ['RS256'] });

          // Add user context headers
          request.headers['x-user-id'] = [{ key: 'X-User-ID', value: decoded.sub }];
          request.headers['x-user-email'] = [{ key: 'X-User-Email', value: decoded.email || '' }];
          request.headers['x-user-roles'] = [{ key: 'X-User-Roles', value: (decoded.roles || []).join(',') }];
          request.headers['x-tenant-id'] = [{ key: 'X-Tenant-ID', value: decoded.tenant_id || '' }];

          return request;
        } catch (err) {
          return {
            status: '401',
            statusDescription: 'Unauthorized',
            headers: {
              'content-type': [{ key: 'Content-Type', value: 'application/json' }]
            },
            body: JSON.stringify({
              error: 'Unauthorized',
              code: 'INVALID_TOKEN',
              message: err.message
            })
          };
        }
      };
    EOT
  }
}

resource "aws_lambda_function" "edge_jwt_validator" {
  provider         = aws.us_east_1
  filename         = data.archive_file.lambda_edge_jwt.output_path
  function_name    = "${local.name_prefix}-edge-jwt-validator"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  publish          = true  # Required for Lambda@Edge
  source_code_hash = data.archive_file.lambda_edge_jwt.output_base64sha256

  timeout     = 5   # Lambda@Edge viewer request max is 5 seconds
  memory_size = 128

  environment {
    variables = {
      JWT_PUBLIC_KEY_SECRET_ARN = var.jwt_public_key_secret_arn
    }
  }

  tags = var.tags
}

###############################################################################
# S3 Origin (for static assets)
###############################################################################

resource "aws_s3_bucket" "static_assets" {
  bucket = "${local.name_prefix}-static-assets"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-static-assets"
  })
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket                  = aws_s3_bucket.static_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.s3_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "static_assets" {
  name                              = "${local.name_prefix}-oac"
  description                       = "OAC for static assets S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "static_assets_cloudfront" {
  bucket = aws_s3_bucket.static_assets.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontRead"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

###############################################################################
# CloudFront Distribution
###############################################################################

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CIAM platform distribution - ${var.environment}"
  default_root_object = "index.html"
  price_class         = var.price_class
  web_acl_id          = var.waf_web_acl_arn
  aliases             = [var.domain_name, "*.${var.domain_name}"]

  # Origin 1: API (ALB)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = var.cloudfront_secret_header
    }
  }

  # Origin 2: Static Assets (S3)
  origin {
    domain_name              = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_assets.id
  }

  # Default cache behavior (API)
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id            = aws_cloudfront_cache_policy.api.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = "${aws_lambda_function.edge_jwt_validator.arn}:${aws_lambda_function.edge_jwt_validator.version}"
      include_body = false
    }
  }

  # Ordered cache behavior for static assets
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Auth endpoints - no caching, no JWT validation
  ordered_cache_behavior {
    path_pattern           = "/api/v1/auth/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.no_caching.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = length(var.blocked_countries) > 0 ? "blacklist" : "none"
      locations        = var.blocked_countries
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate_validation.cloudfront.certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.cf_logs.bucket}.s3.amazonaws.com"
    prefix          = "cloudfront/"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cf"
  })
}

###############################################################################
# CloudFront Policies
###############################################################################

resource "aws_cloudfront_cache_policy" "api" {
  name    = "${local.name_prefix}-api-cache-policy"
  comment = "No cache for API responses"

  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "api" {
  name    = "${local.name_prefix}-api-origin-policy"
  comment = "Forward all headers and query strings to API"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = ["CloudFront-Viewer-Country", "CloudFront-Viewer-City", "CloudFront-Viewer-Latitude", "CloudFront-Viewer-Longitude"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "no_caching" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${local.name_prefix}-security-headers"
  comment = "Security headers for CIAM platform"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https: data:; connect-src 'self' https://*.${var.domain_name}; frame-ancestors 'none';"
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=(self), payment=()"
      override = true
    }
  }
}

###############################################################################
# S3 Bucket for CloudFront Access Logs
###############################################################################

resource "aws_s3_bucket" "cf_logs" {
  bucket = "${local.name_prefix}-cf-access-logs"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cf-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "cf_logs" {
  bucket                  = aws_s3_bucket.cf_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration {
      days = 90
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

###############################################################################
# Route53 DNS Records
###############################################################################

resource "aws_route53_record" "cloudfront_apex" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_wildcard" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
