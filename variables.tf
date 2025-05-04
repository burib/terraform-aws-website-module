
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

variable "cognito_token_issuer_endpoint" {
  description = "Cognito token issuer endpoint. https://cognito-idp.__COGNITO_REGION__.amazonaws.com/__COGNITO_USER_POOL_ID__"
  type        = string
}

variable "auth_urls" {
  type        = map(string)
  description = "Map of authentication URLs"
}

variable "force_destroy_s3_bucket" {
  type        = bool
  description = "Whether to force destroy the S3 bucket"
  default     = false
}

variable "protected_paths" {
  type        = list(string)
  description = "List of paths to protect with authentication"
  default     = ["/dashboard/*"]
}

variable "custom_error_responses" {
  description = "Additional custom error responses to add to CloudFront (useful for SPA routing)"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = optional(number, 60)
  }))
  default = []
}
