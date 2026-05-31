# AWS Settings
# ------------
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

# S3 Settings
# ------------
variable "bucket_name" {
  description = "Unique S3 bucket name for the static website"
  type        = string
}

variable "index_html_path" {
  description = "Filename of the HTML file inside s3_bucket_files/"
  type        = string
  default     = "index.html"
}
 
# CloudFront Settings 
# -------------------
variable "cloudfront_min_ttl" {
  description = "Minimum TTL for CloudFront cache (seconds)"
  type        = number
  default     = 0
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache (seconds)"
  type        = number
  default     = 3600
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront cache (seconds)"
  type        = number
  default     = 86400
}


# GitHub / CodePipeline Settings
# --------------------------------
variable "github_owner" {
  description = "GitHub username or organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "Branch to deploy from"
  type        = string
  default     = "main"
}

variable "s3_bucket_files_dir" {
  description = "Path to the site files directory within the repo (relative to repo root)"
  type        = string
  default     = "s3_bucket_files"
}

# Tags
# ------------
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
