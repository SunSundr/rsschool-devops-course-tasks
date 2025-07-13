output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.flask_app[0].domain_name : null
}

output "flask_app_url" {
  description = "Flask app custom domain URL"
  value       = var.enable_cloudfront ? "https://flask.sunsundr.store" : null
}