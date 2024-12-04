# terraform-aws-website-module ( beta )

#### This module is used to create a static website hosted on s3 bucket with cloudfront distribution and custom domain.
#### The module is able to protect certain routes using lambda@edge with cognito user pool authentication.

# Usage example:

```terraform
module "website" {
  source = "github.com/burib/terraform-aws-ui-module?ref=v0"

  domain_name              = "example.com"
  wildcard_certificate_arn = "REPLACE_WITH_WILDCARD_CERTIFICATE_ARN"
  route53_zone_id          = "REPLACE_WITH_ROUTE53_ZONE_ID_OF_TOP_LEVEL_DOMAIN_LIKE_EXAMPLE_COM"

  environment = "dev" # dev, staging, prod

  # Auth integration
  cognito_client_id             = "REPLACE_WITH_AWS_COGNITO_USER_POOL_CLIENT_ID"
  cognito_domain                = "auth"
  auth_urls                     = "REPLACE_WITH_AUTH_URLS"
  cognito_token_issuer_endpoint = "REPLACE_WITH_COGNITO_TOKEN_ISSUER_ENDPOINT"
}
```
