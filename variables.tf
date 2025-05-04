variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "wedding-photos-front"
}

variable "environment" {
  description = "Environment (e.g. dev, prod, staging)"
  type        = string
  default     = "dev"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub repository branch"
  type        = string
  default     = "main"
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  type        = string
}

variable "build_spec_path" {
  description = "Path to the buildspec.yml file in the repository"
  type        = string
  default     = "buildspec.yml"
}

variable "angular_dist_dir" {
  description = "Directory containing built Angular files inside the dist folder"
  type        = string
  default     = "wedding-photos-front"
}

variable "cloudfront_custom_domain" {
  description = "(Optional) Custom domain name for the CloudFront distribution (e.g., www.example.com)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "The Route 53 Hosted Zone ID for the custom domain. Required if using a custom domain."
  type        = string
  default     = ""
}