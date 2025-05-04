resource "aws_acm_certificate" "cloudfront" {
  domain_name       = var.cloudfront_custom_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name        = "${var.project_name}-${var.environment}-acm"
    Environment = var.environment
  }
}

resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = { for dvo in aws_acm_certificate.cloudfront.domain_validation_options : dvo.domain_name => dvo }
  zone_id = var.route53_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cloudfront" {
  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert_validation : record.fqdn]
}

resource "aws_route53_record" "cloudfront_alias" {
  count   = var.cloudfront_custom_domain != "" && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.cloudfront_custom_domain
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.angular_app.domain_name
    zone_id                = aws_cloudfront_distribution.angular_app.hosted_zone_id
    evaluate_target_health = false
  }
}
