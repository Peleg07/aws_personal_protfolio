data "aws_caller_identity" "current" {}

# Artifact S3 Bucket
# ------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.bucket_name}-pipeline-artifacts"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CodeStar Connection (GitHub)
# ----------------------------
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.bucket_name}-github"
  provider_type = "GitHub"
  tags          = var.tags
}

# IAM — CodePipeline
# ------------------
resource "aws_iam_role" "codepipeline" {
  name = "${var.bucket_name}-codepipeline-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.bucket_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:GetObjectVersion",
          "s3:GetBucketVersioning", "s3:PutObject", "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "codestar-connections:UseConnection"
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = [
          aws_codebuild_project.validate.arn,
          aws_codebuild_project.deploy.arn
        ]
      }
    ]
  })
}

# IAM — CodeBuild (Validate)
# --------------------------
resource "aws_iam_role" "codebuild_validate" {
  name = "${var.bucket_name}-codebuild-validate-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_validate" {
  name = "${var.bucket_name}-codebuild-validate-policy"
  role = aws_iam_role.codebuild_validate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.bucket_name}-validate",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.bucket_name}-validate:log-stream:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

# IAM — CodeBuild (Deploy)
# ------------------------
resource "aws_iam_role" "codebuild" {
  name = "${var.bucket_name}-codebuild-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.bucket_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.bucket_name}-deploy",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.bucket_name}-deploy:log-stream:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.website.id}"
      }
    ]
  })
}

# CodeBuild Project — Validate
# ----------------------------
resource "aws_codebuild_project" "validate" {
  name          = "${var.bucket_name}-validate"
  service_role  = aws_iam_role.codebuild_validate.arn
  build_timeout = 5
  tags          = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "SITE_DIR"
      value = var.s3_bucket_files_dir
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        install:
          runtime-versions:
            nodejs: 18
          commands:
            - npm install -g htmlhint
        build:
          commands:
            - echo "Validating HTML syntax in $SITE_DIR/index.html"
            - htmlhint "$SITE_DIR/index.html"
    BUILDSPEC
  }
}

# CodeBuild Project — Deploy
# --------------------------
resource "aws_codebuild_project" "deploy" {
  name          = "${var.bucket_name}-deploy"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10
  tags          = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "WEBSITE_BUCKET"
      value = aws_s3_bucket.website.id
    }

    environment_variable {
      name  = "CF_DIST_ID"
      value = aws_cloudfront_distribution.website.id
    }

    environment_variable {
      name  = "SITE_DIR"
      value = var.s3_bucket_files_dir
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        build:
          commands:
            - echo "Syncing $SITE_DIR to s3://$WEBSITE_BUCKET"
            - aws s3 sync $SITE_DIR/ s3://$WEBSITE_BUCKET/ --delete
            - echo "Invalidating CloudFront distribution $CF_DIST_ID"
            - aws cloudfront create-invalidation --distribution-id $CF_DIST_ID --paths "/*"
    BUILDSPEC
  }
}

# CodePipeline
# ------------
resource "aws_codepipeline" "website" {
  name     = "${var.bucket_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  tags     = var.tags

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = "${var.github_owner}/${var.github_repo}"
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Validate"
    action {
      name            = "Validate_HTML"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.validate.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy_to_S3"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }
}

# Outputs
# -------
output "codestar_connection_arn" {
  value       = aws_codestarconnections_connection.github.arn
  description = "IMPORTANT: Activate this connection manually in AWS Console > Developer Tools > Connections"
}

output "pipeline_name" {
  value       = aws_codepipeline.website.name
  description = "CodePipeline name"
}
