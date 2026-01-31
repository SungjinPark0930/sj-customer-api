resource "aws_s3_bucket" "example" {
  bucket = "S3_BUCKET_NAME_VALUE"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "PUT", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
  }

  object_lock_enabled = true

  tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = "S3_BUCKET_NAME_VALUE"
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "example" {
  bucket = "S3_BUCKET_NAME_VALUE"
  target_bucket = "LOG_BUCKET_NAME_VALUE"
  target_prefix = "S3_BUCKET_NAME_VALUE"
}
