# S3 bucket for pipeline artifacts
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.project_name}-${var.environment}-pipeline"
  tags = {
    Name        = "${var.project_name}-${var.environment}-pipeline"
    Environment = var.environment
  }
}

# CodeBuild role
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-${var.environment}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CodeBuild policy
resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.angular_app.arn,
          "${aws_s3_bucket.angular_app.arn}/*",
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      }
    ]
  })
}

# CodePipeline role
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CodePipeline policy
resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-${var.environment}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.angular_app.arn,
          "${aws_s3_bucket.angular_app.arn}/*",
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = var.github_connection_arn
      },
      {
        Effect = "Allow",
        Action = ["lambda:InvokeFunction"],
        Resource = aws_lambda_function.cloudfront_invalidate.arn
      }
    ]
  })
}

# CodeBuild project for Angular
resource "aws_codebuild_project" "angular_build" {
  name          = "${var.project_name}-${var.environment}-build"
  description   = "Build Angular application"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.angular_app.bucket
    }

    environment_variable {
      name  = "ANGULAR_DIST_DIR"
      value = var.angular_dist_dir
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec.yml")
  }
}

# IAM role for Lambda function
resource "aws_iam_role" "cloudfront_invalidate_lambda" {
  name = "${var.project_name}-${var.environment}-cloudfront-invalidate-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "cloudfront_invalidate_lambda" {
  role = aws_iam_role.cloudfront_invalidate_lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codepipeline:PutJobSuccessResult",
          "codepipeline:PutJobFailureResult"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Lambda function for CloudFront cache invalidation
resource "aws_lambda_function" "cloudfront_invalidate" {
  filename         = "lambda_cloudfront_invalidate.zip"
  function_name    = "${var.project_name}-${var.environment}-cloudfront-invalidate"
  role             = aws_iam_role.cloudfront_invalidate_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 600  # Set timeout to 10 minutes to allow for CloudFront invalidation to complete
  source_code_hash = filebase64sha256("lambda_cloudfront_invalidate.zip")
  environment {
    variables = {
      DISTRIBUTION_ID = aws_cloudfront_distribution.angular_app.id
    }
  }
}

# V2 CodePipeline
resource "aws_codepipeline" "angular_pipeline" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  pipeline_type  = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "BuildAngular"
    action {
      name             = "BuildAngular"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.angular_build.name
      }
    }
  }

  stage {
    name = "DeployToS3"
    action {
      name            = "DeployToS3"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        BucketName = aws_s3_bucket.angular_app.bucket
        Extract    = "true"
      }
    }
  }

  stage {
    name = "InvalidateCloudFront"
    action {
      name             = "InvalidateCache"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "Lambda"
      version          = "1"
      input_artifacts  = []
      configuration = {
        FunctionName = aws_lambda_function.cloudfront_invalidate.function_name
      }
      run_order = 1
    }
  }
}