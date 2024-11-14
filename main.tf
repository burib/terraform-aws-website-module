
# Usage example:
#```hcl
# module "website" {
#   source = "github.com/burib/terraform-aws-ui-module?ref=init"
#
#   domain_name              = "example.com"
#   environment             = "prod"
#   wildcard_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
#   route53_zone_id         = "ZXXXXXXXXXXXXX"
#   redirect_www_to_https   = true  # Optional, defaults to true
#
#   tags = {
#     Environment = "prod"
#     Project     = "website"
#   }
# }
#```
# main.tf

#############################
# Variables
#############################

variable "domain_name" {
  type        = string
  description = "Domain name for the website"
}

variable "environment" {
  description = <<EOF
    Environment variable used to tag resources created by this module.

    **Example values are:**
      - temp
      - dev
      - staging
      - prod

    **Notes:**
      Put here your notes if there is any.
  EOF
  type        = string
}

variable "wildcard_certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate to use for CloudFront"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 zone ID for DNS records"
}

variable "redirect_www_to_https" {
  type        = bool
  description = "Whether to redirect www to https non-www domain"
  default     = true
}

variable "api_domain" {
  type        = string
  description = "API Gateway custom domain (e.g., api.example.com)"
  default     = null
}

variable "auth_domain" {
  type        = string
  description = "Custom domain for Cognito auth (e.g., auth.example.com)"
  default     = null
}

variable "enable_auth" {
  type        = bool
  description = "Enable authentication setup"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "price_class" {
  type        = string
  description = "CloudFront price class: PriceClass_All, PriceClass_200, PriceClass_100"
  default     = "PriceClass_All"
}

variable "custom_error_ttl" {
  type = map(number)
  description = "Custom TTL for error pages"
  default = {
    403 = 3600    # 1 hour
    404 = 86400   # 24 hours
    500 = 3600    # 1 hour
    503 = 3600    # 1 hour
  }
}

variable "cloudfront_minimum_protocol_version" {
  type        = string
  description = "Minimum TLS version for CloudFront"
  default     = "TLSv1.2_2021"
}

#############################
# Locals
#############################

locals {
  times = {
    oneHour  = 3600
    oneDay   = 86400
    oneWeek  = 604800
    oneMonth = 2592000
  }

  bucket_name     = "${var.domain_name}-${random_id.bucket_suffix.hex}"
  www_bucket_name = "www-${var.domain_name}-${random_id.bucket_suffix.hex}"
  s3_origin_id    = "S3-${local.bucket_name}"
  www_domain      = "www.${var.domain_name}"
  api_domain      = coalesce(var.api_domain, "api.${var.domain_name}")
  auth_domain     = coalesce(var.auth_domain, "auth.${var.domain_name}")
  website_domain = "${aws_s3_bucket.website.id}.s3.${data.aws_region.current.name}.amazonaws.com"

  cache_settings = {
    static = {
      min_ttl     = local.times.oneDay
      default_ttl = local.times.oneWeek
      max_ttl     = local.times.oneMonth
      compress    = true
    }
    dynamic = {
      min_ttl     = 0
      default_ttl = local.times.oneHour
      max_ttl     = local.times.oneDay
      compress    = true
    }
  }

  static_paths = ["*.css", "*.js", "*.jpg", "*.jpeg", "*.png", "*.gif", "*.ico", "*.svg", "*.woff", "*.woff2", "*.ttf", "*.eot"]
  
  protected_paths = var.enable_auth ? ["/*"] : []
  public_paths = var.enable_auth ? [
    "/",
    "/login",
    "/logout",
    "/callback",
    "/assets/*",
    "/static/*",
    "/*.ico",
    "/*.png",
    "/*.svg",
    "/error_*.html"
  ] : []

  error_pages = {
    "error_403.html" = {
      title   = "Access Denied"
      message = "You don't have permission to access this page."
    }
    "error_404.html" = {
      title   = "Page Not Found"
      message = "The page you're looking for doesn't exist."
    }
    "error_500.html" = {
      title   = "Server Error"
      message = "Something went wrong on our end."
    }
    "error_503.html" = {
      title   = "Service Unavailable"
      message = "The service is temporarily unavailable. Please try again later."
    }
  }
}

#############################
# Random ID Generator
#############################

resource "random_id" "bucket_suffix" {
  byte_length = 4
  
  keepers = {
    domain_name = var.domain_name
  }
}

#############################
# S3 Resources
#############################

# Primary website bucket
resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Update public access block settings
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Update bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "website" {
  depends_on = [aws_s3_bucket_public_access_block.website]
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn": aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# Add Origin Access Control
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = var.domain_name
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# WWW redirect bucket
resource "aws_s3_bucket" "www_redirect" {
  count  = var.redirect_www_to_https ? 1 : 0
  bucket = local.www_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_website_configuration" "www_redirect" {
  count  = var.redirect_www_to_https ? 1 : 0
  bucket = aws_s3_bucket.www_redirect[0].id

  redirect_all_requests_to {
    host_name = var.domain_name
    protocol  = "https"
  }
}

# Logging bucket
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${local.bucket_name}-cf-logs"

  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]

  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "cloudfront_logs_policy" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontLogging"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudfront_logs.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "cleanup_old_logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

# Store bucket name in SSM Parameter Store
resource "aws_ssm_parameter" "bucket_name" {
  name        = "/${var.domain_name}/website/s3_bucket_name"
  description = "S3 bucket name for ${var.domain_name} website. Use this when you need to sync the UI dist files to s3."
  type        = "String"
  value       = local.bucket_name
  tags        = var.tags
  overwrite   = true
}

#############################
# S3 Objects
#############################

# Initial index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"
  
  content = <<EOF
<!DOCTYPE html>
<html lang="en" style="height: 100%; margin: 0; padding: 0;">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${var.domain_name}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            background-color: rgb(168, 105, 193);
            background-image: url("https://d2k1ftgv7pobq7.cloudfront.net/images/backgrounds/gradients/rainbow.svg");
            background-size: cover;
            background-position: center center;
            color: white;
            text-align: center;
        }

        .container {
            padding: 2rem;
            max-width: 800px;
            width: 90%;
        }

        h1 {
            font-size: clamp(2rem, 5vw, 3.5rem);
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }

        p {
            font-size: clamp(1rem, 2vw, 1.25rem);
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${var.domain_name}</h1>
        <p>It works.</p>
    </div>
</body>
</html>
EOF

  lifecycle {
    ignore_changes = [
      etag,
      content_type,
      content,
      content_base64,
      metadata
    ]
  }
}

# Error pages
resource "aws_s3_object" "error_pages" {
  for_each = local.error_pages

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = "text/html"
  
  content = <<EOF
<!DOCTYPE html>
<html lang="en" style="height: 100%; margin: 0; padding: 0;">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${each.value.title} - ${var.domain_name}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            margin: 0;
            padding: 0;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            background-color: rgb(168, 105, 193);
            background-image: url("https://d2k1ftgv7pobq7.cloudfront.net/images/backgrounds/gradients/rainbow.svg");
            background-size: cover;
            background-position: center center;
            color: white;
            text-align: center;
        }

        .container {
            padding: 2rem;
            max-width: 800px;
            width: 90%;
        }

        h1 {
            font-size: clamp(2rem, 5vw, 3.5rem);
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }

        p {
            font-size: clamp(1rem, 2vw, 1.25rem);
            opacity: 0.9;
        }

        .back-link {
            margin-top: 2rem;
            color: white;
            text-decoration: none;
            font-size: 1.1rem;
            padding: 0.5rem 1rem;
            border: 2px solid white;
            border-radius: 4px;
            transition: all 0.3s ease;
        }

        .back-link:hover {
            background: rgba(255, 255, 255, 0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>${each.value.title}</h1>
        <p>${each.value.message}</p>
        <a href="/" class="back-link">Back to Homepage</a>
    </div>
</body>
</html>
EOF

  lifecycle {
    ignore_changes = [
      etag,
      content_type,
      content,
      content_base64,
      metadata
    ]
  }

  tags = var.tags
}

#############################
# CloudFront Resources
#############################

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled    = true
  http_version       = "http2and3"
  default_root_object = "index.html"
  aliases            = var.redirect_www_to_https ? [var.domain_name, local.www_domain] : [var.domain_name]
  price_class        = var.price_class
  tags               = var.tags
  
  web_acl_id = null

  # Update CloudFront origin configuration
  origin {
    domain_name              = local.website_domain
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  logging_config {
    include_cookies = false
    bucket         = "${aws_s3_bucket.cloudfront_logs.bucket}.s3.amazonaws.com"
    prefix         = "cloudfront/"
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress              = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.check_host.arn
    }

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Host", "Authorization"]
      
      cookies {
        forward = var.enable_auth ? "whitelist" : "none"
        whitelisted_names = var.enable_auth ? [
          "CognitoIdentityServiceProvider.*",
          "cognito-flow-*",
          "TOKEN",
          "ID_TOKEN",
          "ACCESS_TOKEN"
        ] : []
      }
    }

    min_ttl     = local.cache_settings.dynamic.min_ttl
    default_ttl = local.cache_settings.dynamic.default_ttl
    max_ttl     = local.cache_settings.dynamic.max_ttl
  }

  # Static files cache behavior
  dynamic "ordered_cache_behavior" {
    for_each = toset(local.static_paths)
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id

      forwarded_values {
        query_string = false
        headers      = ["Origin"]
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      compress              = true

      min_ttl     = local.cache_settings.static.min_ttl
      default_ttl = local.cache_settings.static.default_ttl
      max_ttl     = local.cache_settings.static.max_ttl
    }
  }

  # Auth paths cache behavior (if auth enabled)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_auth ? [1] : []
    content {
      path_pattern     = "/auth/*"
      allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id

      forwarded_values {
        query_string = true
        headers      = ["Origin", "Authorization"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      compress              = true
      min_ttl               = 0
      default_ttl           = 0
      max_ttl               = 0
    }
  }

  custom_error_response {
    error_code            = 403
    response_page_path    = "/error_403.html"
    error_caching_min_ttl = var.custom_error_ttl[403]
    response_code         = 403
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/error_404.html"
    error_caching_min_ttl = var.custom_error_ttl[404]
    response_code         = 404
  }

  custom_error_response {
    error_code            = 500
    response_page_path    = "/error_500.html"
    error_caching_min_ttl = var.custom_error_ttl[500]
    response_code         = 500
  }

  custom_error_response {
    error_code            = 503
    response_page_path    = "/error_503.html"
    error_caching_min_ttl = var.custom_error_ttl[503]
    response_code         = 503
  }

  viewer_certificate {
    acm_certificate_arn      = var.wildcard_certificate_arn
    minimum_protocol_version = var.cloudfront_minimum_protocol_version
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

#############################
# Route53 Records
#############################

# Primary A record
resource "aws_route53_record" "website" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# WWW A record (if redirect is enabled)
resource "aws_route53_record" "www" {
  count   = var.redirect_www_to_https ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.www_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Primary AAAA record (IPv6)
resource "aws_route53_record" "website_ipv6" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# WWW AAAA record (IPv6) (if redirect is enabled)
resource "aws_route53_record" "www_ipv6" {
  count   = var.redirect_www_to_https ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.www_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

#############################
# Outputs
#############################

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "The ID of the CloudFront distribution"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.website.domain_name
  description = "The domain name of the CloudFront distribution"
}

output "website_url" {
  value       = "https://${var.domain_name}"
  description = "The URL of the website"
}

output "www_url" {
  value       = var.redirect_www_to_https ? "https://www.${var.domain_name}" : null
  description = "The www URL of the website (if enabled)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "The name of the S3 bucket"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.website.arn
  description = "The ARN of the S3 bucket"
}

output "www_bucket_name" {
  value       = var.redirect_www_to_https ? aws_s3_bucket.www_redirect[0].id : null
  description = "The name of the www redirect S3 bucket (if enabled)"
}

output "logs_bucket_name" {
  value       = aws_s3_bucket.cloudfront_logs.id
  description = "The name of the logging bucket"
}

output "ssm_parameter_name" {
  value       = aws_ssm_parameter.bucket_name.name
  description = "SSM parameter name storing the bucket name"
}

output "cloudfront_function_host_check_arn" {
  value       = aws_cloudfront_function.check_host.arn
  description = "The ARN of the CloudFront host check function"
}

output "api_domain" {
  value       = local.api_domain
  description = "The API domain name"
}

output "auth_domain" {
  value       = local.auth_domain
  description = "The auth domain name"
}

output "auth_enabled" {
  value       = var.enable_auth
  description = "Whether authentication is enabled"
}
