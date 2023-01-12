# https://gist.github.com/danihodovic/a51eb0d9d4b29649c2d094f4251827dd
# https://github.com/skyscrapers/terraform-website-s3-cloudfront-route53

# S3

resource "aws_s3_bucket" "website" {
  bucket        = var.s3_bucket_name
  force_destroy = var.force_destroy
}
data "template_file" "bucket_policy_file" {
  template = file("./website_bucket_policy.json")

  vars = {
    bucket = var.s3_bucket_name
  }
}
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.bucket
  policy = data.template_file.bucket_policy_file.rendered
}
resource "aws_s3_bucket_website_configuration" "website_configure" {
  bucket = aws_s3_bucket.website.bucket

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# IAM Policy
data "template_file" "deployer_role_policy_file" {
  template = file("./deployer_role_policy.json")

  vars = {
    bucket = var.s3_bucket_name
  }
}
resource "aws_iam_policy" "site_deployer_policy" {
  count = var.deployer != null ? 1 : 0

  name        = "${var.s3_bucket_name}.deployer"
  path        = "/"
  description = "Policy allowing to publish a new version of the website to the S3 bucket"
  policy      = data.template_file.deployer_role_policy_file.rendered
}
resource "aws_iam_policy_attachment" "site-deployer-attach-user-policy" {
  count = var.deployer != null ? 1 : 0

  name       = "${var.s3_bucket_name}-deployer-policy-attachment"
  users      = [var.deployer]
  policy_arn = aws_iam_policy.site_deployer_policy.0.arn
}



# Cloudfront
resource "aws_cloudfront_distribution" "cdn" {
  enabled         = true
  is_ipv6_enabled = var.ipv6
  price_class     = var.price_class
  http_version    = "http2"

  origin {
    origin_id   = aws_s3_bucket.website.id
    domain_name = aws_s3_bucket_website_configuration.website_configure.website_endpoint

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }

    # custom_header {
    #   name  = "User-Agent"
    #   value = var.duplicate-content-penalty-secret
    # }
  }

  default_root_object = var.default-root-object

  custom_error_response {
    error_code            = "404"
    error_caching_min_ttl = "360"
    response_code         = var.not-found-response-code
    response_page_path    = var.not-found-response-path
  }

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = var.forward-query-string

      cookies {
        forward = "none"
      }
    }

    trusted_signers = var.trusted_signers

    min_ttl          = "0"
    default_ttl      = "300"  //3600
    max_ttl          = "1200" //86400
    target_origin_id = aws_s3_bucket.website.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # This is required to be specified even if it's not used.
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm-certificate-arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = var.minimum_client_tls_protocol_version
  }

  aliases = ["${var.sub_domain}.${var.domain}"]
  tags = {
    Name = "tony"
  }
}


# Route53
data "aws_route53_zone" "alocados_zone" {
  name = var.domain
}
resource "aws_route53_record" "tony_record" {
  zone_id = data.aws_route53_zone.alocados_zone.zone_id
  name    = "${var.sub_domain}.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}