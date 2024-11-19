# Usage example:
#```hcl
# module "website" {
#   source = "github.com/burib/terraform-aws-ui-module?ref=v0"
#
#   domain_name              = "example.com"
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
# ui/main.tf

# Variables
variable "domain_name" {
  type        = string
  description = "Domain name for the website"
}

variable "wildcard_certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate to use for CloudFront"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 zone ID for DNS records"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., prod, dev)"
}

variable "cognito_client_id" {
  type        = string
  description = "Cognito User Pool Client ID"
}

variable "cognito_domain" {
  type        = string
  description = "Cognito domain name"
}

variable "auth_urls" {
  type        = map(string)
  description = "Map of authentication URLs"
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
  bucket_name     = "${var.domain_name}-${random_id.bucket_suffix.hex}"
  www_bucket_name = "www-${var.domain_name}-${random_id.bucket_suffix.hex}"
  s3_origin_id    = "S3-${local.bucket_name}"
  www_domain      = "www.${var.domain_name}"

  auth_handler_code = <<-EOF
    function handler(event) {
        var request = event.request;
        var uri = request.uri;
        var host = request.headers.host.value;
        
        // Auth route handling
        const authRoutes = {
            "${var.auth_urls.sign_in}": {
                redirect: true,
                path: `https://${var.cognito_domain}/oauth2/authorize?client_id=${var.cognito_client_id}&response_type=code&scope=email+openid+profile&redirect_uri=https://${var.domain_name}${var.auth_urls.callback}`
            },
            "${var.auth_urls.callback}": {
                redirect: false,
                path: "/auth/callback.html"
            },
            "${var.auth_urls.signed_out}": {
                redirect: false,
                path: "/auth/signed-out.html"
            },
            "${var.auth_urls.error}": {
                redirect: false,
                path: "/auth/error.html"
            }
        };

        if (uri in authRoutes) {
            const route = authRoutes[uri];
            if (route.redirect) {
                return {
                    statusCode: 302,
                    statusDescription: "Found",
                    headers: {
                        "location": { value: route.path },
                        "cache-control": { value: "no-cache, no-store, must-revalidate" }
                    }
                };
            } else {
                request.uri = route.path;
                return request;
            }
        }

        return request;
    }
  EOF

  auth_pages = {
    "auth/callback.html" = {
      title = "Authentication Callback"
      content = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Authentication - ${var.domain_name}</title>
            <script>
                function handleCallback() {
                    const urlParams = new URLSearchParams(window.location.search);
                    const code = urlParams.get('code');
                    
                    if (code) {
                        // Store the auth code temporarily
                        sessionStorage.setItem('auth_code', code);
                        // Store timestamp for expiry check
                        sessionStorage.setItem('auth_timestamp', Date.now());
                        // Redirect to home
                        window.location.href = '/';
                    } else {
                        window.location.href = '${var.auth_urls.error}';
                    }
                }
                // Execute on load
                handleCallback();
            </script>
        </head>
        <body>
            <h1>Completing Sign In...</h1>
        </body>
        </html>
      HTML
    }
    "auth/signed-out.html" = {
      title = "Signed Out"
      content = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Signed Out - ${var.domain_name}</title>
            <script>
                function handleSignOut() {
                    // Clear auth data
                    sessionStorage.clear();
                    localStorage.clear();
                    // Redirect to home after a brief delay
                    setTimeout(() => {
                        window.location.href = '/';
                    }, 1500);
                }
                // Execute on load
                handleSignOut();
            </script>
            <style>
                body {
                    font-family: 'Inter', -apple-system, system-ui, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background-color: #f9fafb;
                }
                .container {
                    text-align: center;
                    padding: 2rem;
                }
                h1 { color: #111827; }
                p { color: #6b7280; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>You've been signed out</h1>
                <p>Redirecting you to the homepage...</p>
            </div>
        </body>
        </html>
      HTML
    }
    "auth/error.html" = {
      title = "Authentication Error"
      content = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Authentication Error - ${var.domain_name}</title>
            <style>
                body {
                    font-family: 'Inter', -apple-system, system-ui, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background-color: #f9fafb;
                }
                .container {
                    text-align: center;
                    padding: 2rem;
                }
                h1 { color: #111827; }
                p { color: #6b7280; }
                .button {
                    display: inline-block;
                    margin-top: 1rem;
                    padding: 0.5rem 1rem;
                    background-color: #3b82f6;
                    color: white;
                    text-decoration: none;
                    border-radius: 0.375rem;
                    transition: background-color 0.2s;
                }
                .button:hover {
                    background-color: #2563eb;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Authentication Error</h1>
                <p>Sorry, we couldn't complete the authentication process.</p>
                <a href="${var.auth_urls.sign_in}" class="button">Try Again</a>
            </div>
        </body>
        </html>
      HTML
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

# CloudFront Function for Auth Handling
resource "aws_cloudfront_function" "auth_handler" {
  name    = "${var.domain_name}-auth-handler"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = local.auth_handler_code
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

# Authentication Pages
resource "aws_s3_object" "auth_pages" {
  for_each = local.auth_pages

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = "text/html"
  content      = each.value.content

  lifecycle {
    ignore_changes = [
      etag,
      content_type,
      metadata
    ]
  }
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
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  # Default cache behavior with auth function
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress              = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.auth_handler.arn
    }

    forwarded_values {
      query_string = true  # Enable for auth handling
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Custom error responses
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
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

output "cloudfront_function_name" {
  value       = aws_cloudfront_function.auth_handler.name
  description = "The name of the CloudFront function for auth handling"
}
