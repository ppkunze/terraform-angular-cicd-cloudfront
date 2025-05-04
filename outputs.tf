output "project_info" {
  description = "Information about the project deployment"
  value = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
  }
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.angular_pipeline.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the Angular app"
  value       = aws_s3_bucket.angular_app.bucket
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution for the Angular app"
  value       = aws_cloudfront_distribution.angular_app.domain_name
}