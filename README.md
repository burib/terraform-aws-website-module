# terraform-aws-website-module ( beta )


# Usage example:
```terraform
module "website" {
   source = "github.com/burib/terraform-aws-ui-module?ref=v0"

   domain_name              = "example.com"
   environment              = "prod"
   wildcard_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
   route53_zone_id          = "ZXXXXXXXXXXXXX"
 }
```
