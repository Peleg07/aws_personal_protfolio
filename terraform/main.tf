terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket
# ---------
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

# enable public access to the bucket
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# Upload Files
# ------------
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../s3_bucket_files/${var.index_html_path}"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../s3_bucket_files/${var.index_html_path}")
}

resource "aws_s3_object" "portfolio_image" {
  bucket       = aws_s3_bucket.website.id
  key          = "protfolio_image.png"
  source       = "${path.module}/../s3_bucket_files/protfolio_image.png"
  content_type = "image/png"
  etag         = filemd5("${path.module}/../s3_bucket_files/protfolio_image.png")
}

resource "aws_s3_object" "cv_pdf" {
  bucket       = aws_s3_bucket.website.id
  key          = "Peleg_Levy_CV.pdf"
  source       = "${path.module}/../s3_bucket_files/Peleg_Levy_CV.pdf"
  content_type = "application/pdf"
  etag         = filemd5("${path.module}/../s3_bucket_files/Peleg_Levy_CV.pdf")
}

# CloudFront Distribution
# -----------------------
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "s3-website-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-website-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = var.cloudfront_min_ttl
    default_ttl = var.cloudfront_default_ttl
    max_ttl     = var.cloudfront_max_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

# Outputs
# --------
output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
  description = "Your website URL"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.website.id
}
