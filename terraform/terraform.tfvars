# aws global vars
aws_region = "eu-central-1"

# S3 settings
bucket_name     = "peleg-landing-page"  # Must be globally unique
index_html_path = "index.html"

# GitHub / CodePipeline Settings
github_owner        = "Peleg07"
github_repo         = "aws_personal_protfolio"
github_branch       = "main"
s3_bucket_files_dir = "s3_bucket_files"  # relative path inside the repo

# CloudFront Settings
cloudfront_min_ttl     = 0
cloudfront_default_ttl = 3600
cloudfront_max_ttl     = 86400

# Tags
tags = {
  Project     = "landing-page"
  Environment = "production"
  ManagedBy   = "terraform"
}
