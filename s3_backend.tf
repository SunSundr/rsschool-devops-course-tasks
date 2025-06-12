resource "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_S3_bucket
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}