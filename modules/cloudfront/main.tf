# CloudFront distribution for Flask app
data "aws_route53_zone" "main" {
  name = "sunsundr.store"
}

# Create origin subdomain that points to bastion IP
resource "aws_route53_record" "flask_origin" {
  count   = var.enable_cloudfront && var.bastion_public_ip != null ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "flask-origin.sunsundr.store"
  type    = "A"
  ttl     = 300
  records = [var.bastion_public_ip]

  lifecycle {
    ignore_changes = [records]
  }
}

# Use existing SSL certificate (created manually in AWS Console)
data "aws_acm_certificate" "flask_app" {
  count    = var.enable_cloudfront ? 1 : 0
  provider = aws.us_east_1

  domain   = "flask.sunsundr.store"
  statuses = ["ISSUED"]
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "flask_app" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name = aws_route53_record.flask_origin[0].fqdn
    origin_id   = "flask-app-origin"

    custom_origin_config {
      http_port              = 8080
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  aliases = ["flask.sunsundr.store"]

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "flask-app-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.flask_app[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${var.project}-flask-app-cloudfront"
  }

  depends_on = [
    aws_route53_record.flask_origin
  ]
}

# Route53 record for flask.sunsundr.store
resource "aws_route53_record" "flask_app" {
  count   = var.enable_cloudfront ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "flask.sunsundr.store"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.flask_app[0].domain_name
    zone_id                = aws_cloudfront_distribution.flask_app[0].hosted_zone_id
    evaluate_target_health = false
  }
}