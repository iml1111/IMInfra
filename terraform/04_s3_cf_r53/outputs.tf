output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_configure.website_endpoint
}

output "route53_domain" {
  value = aws_route53_record.tony_record.fqdn
}

output "cdn_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}