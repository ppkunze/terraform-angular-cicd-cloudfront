# CloudFront Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "angular_app" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for S3 origin of Angular app"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "angular_app" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.angular_app.bucket_regional_domain_name
    origin_id                = "s3-angular-app"
    origin_access_control_id = aws_cloudfront_origin_access_control.angular_app.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-angular-app"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  aliases = var.cloudfront_custom_domain != "" ? [var.cloudfront_custom_domain] : []

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.cloudfront.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cf"
    Environment = var.environment
  }
}
