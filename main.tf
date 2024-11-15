# Usage example:
#```hcl
# module "website" {
#   source = "github.com/burib/terraform-aws-ui-module?ref=v0"
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

# Variables
variable "domain_name" {
  type        = string
  description = "Domain name for the website"
}

variable "environment" {
  type        = string
  description = "Environment (dev/staging/prod)"
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

variable "cloudfront_minimum_protocol_version" {
  type        = string
  description = "Minimum TLS version for CloudFront"
  default     = "TLSv1.2_2021"
}

# Locals
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

# Random ID Generator
resource "random_id" "bucket_suffix" {
  byte_length = 4
  keepers = {
    domain_name = var.domain_name
  }
}

# S3 Resources
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

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = var.domain_name
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy for CloudFront
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

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled    = true
  http_version       = "http2and3"
  default_root_object = "index.html"
  aliases            = var.redirect_www_to_https ? [var.domain_name, local.www_domain] : [var.domain_name]
  price_class        = var.price_class
  tags               = var.tags

  origin {
    domain_name              = "${aws_s3_bucket.website.bucket}.s3.${data.aws_region.current.name}.amazonaws.com"
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress              = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = local.cache_settings.dynamic.min_ttl
    default_ttl = local.cache_settings.dynamic.default_ttl
    max_ttl     = local.cache_settings.dynamic.max_ttl
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(local.static_paths)
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = local.s3_origin_id
      compress        = true

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl     = local.cache_settings.static.min_ttl
      default_ttl = local.cache_settings.static.default_ttl
      max_ttl     = local.cache_settings.static.max_ttl
    }
  }

  custom_error_response {
    error_code            = 403
    response_page_path    = "/error_403.html"
    error_caching_min_ttl = 3600
    response_code         = 403
  }

  custom_error_response {
    error_code            = 404
    response_page_path    = "/error_404.html"
    error_caching_min_ttl = 3600
    response_code         = 404
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

# Route53 Records
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

# Outputs
output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "The ID of the CloudFront distribution"
}

output "website_url" {
  value       = "https://${var.domain_name}"
  description = "The URL of the website"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "The name of the S3 bucket"
}
