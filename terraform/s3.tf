# ── Model artifacts bucket ────────────────────────────────────────────────────

resource "aws_s3_bucket" "models" {
  bucket = "${local.name_prefix}-${var.model_bucket_name}"
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Frontend static assets bucket ─────────────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-${var.frontend_bucket_name}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: allow CloudFront OAC to read objects
resource "aws_s3_bucket_policy" "frontend" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend[0].arn
        }
      }
    }]
  })
}

# ── Lambda deployment zips bucket ─────────────────────────────────────────────
# Zips are uploaded by CI/CD before terraform apply.

resource "aws_s3_bucket" "lambda_zips" {
  bucket = "${local.name_prefix}-lambda-zips"
}

resource "aws_s3_bucket_public_access_block" "lambda_zips" {
  bucket                  = aws_s3_bucket.lambda_zips.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
