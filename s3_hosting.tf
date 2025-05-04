# S3 bucket for hosting Angular application
resource "aws_s3_bucket" "angular_app" {
  bucket = "${var.project_name}-${var.environment}"
  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

# Block public access for S3 bucket (changed from public to private)
resource "aws_s3_bucket_public_access_block" "angular_app" {
  bucket = aws_s3_bucket.angular_app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy to allow CloudFront (using OAC) to read objects from the S3 bucket
resource "aws_s3_bucket_policy" "angular_app_cloudfront" {
  bucket = aws_s3_bucket.angular_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.angular_app.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.angular_app.arn
          }
        }
      }
    ]
  })
}