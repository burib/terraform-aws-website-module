output "region" {
  value       = local.region
  description = "AWS Region code where this stack has been deployed to."
}

output "account_id" {
  value       = local.account_id
  description = "AWS Account ID where this stack has been deployed to."
}

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

output "domain_records_created" {
  value = {
    a_record    = aws_route53_record.website.name
    aaaa_record = aws_route53_record.website_ipv6.name
    www_records = var.redirect_www_to_https ? [aws_route53_record.www[0].name, aws_route53_record.www_ipv6[0].name] : []
  }
}