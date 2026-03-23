# --- 1. PROVIDER & RANDOM ID ---
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --- 2. S3 BUCKET (THE BUNKER) ---
resource "aws_s3_bucket" "media_storage" {
  bucket = "pro-movie-storage-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Media Storage"
    Project     = "Video-Transcoder"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "media_storage_block" {
  bucket = aws_s3_bucket.media_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "media_storage_versioning" {
  bucket = aws_s3_bucket.media_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media_storage_encryption" {
  bucket = aws_s3_bucket.media_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- 3. CLOUDFRONT ORIGIN ACCESS CONTROL (THE KEY) ---
resource "aws_cloudfront_origin_access_control" "movies_oac" {
  name                              = "movies-bucket-oac"
  description                       = "OAC for the movie storage bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- 4. CLOUDFRONT DISTRIBUTION (THE GATEWAY) ---
locals {
  s3_origin_id = "S3-MediaStorage"
  project_root = path.module 
}

resource "aws_cloudfront_distribution" "media_distribution" {
  # ELIMINADO: aliases (No tenemos dominio propio aún)

  origin {
    domain_name              = aws_s3_bucket.media_storage.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.movies_oac.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for movie streaming"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

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

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CAMBIADO: Usamos el certificado estándar de CloudFront
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Environment = "Dev"
  }
}

# --- 5. BUCKET POLICY (THE PERMISSION) ---
data "aws_iam_policy_document" "s3_allow_access_from_cloudfront" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.media_storage.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.media_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.media_storage.id
  policy = data.aws_iam_policy_document.s3_allow_access_from_cloudfront.json
}

# --- 6. FILE UPLOADS (THE CONTENT) ---
resource "aws_s3_object" "frontend" {
  bucket       = aws_s3_bucket.media_storage.id
  key          = "index.html"
  source       = "${local.project_root}/index.html"
  content_type = "text/html"
  etag         = filemd5("${local.project_root}/index.html")
}

# Este bloque subirá lo que tengas en la carpeta /movies de tu escritorio
resource "aws_s3_object" "movies" {
  for_each = fileset("${local.project_root}/movies/", "*.mp4")

  bucket       = aws_s3_bucket.media_storage.id
  key          = each.value
  source       = "${local.project_root}/movies/${each.value}"
  content_type = "video/mp4"
  etag         = filemd5("${local.project_root}/movies/${each.value}")
}

# --- 7. OUTPUTS ---
output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.media_distribution.domain_name}"
  description = "SHARE THIS URL WITH YOUR COUSIN! 🎬"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.media_storage.id
}