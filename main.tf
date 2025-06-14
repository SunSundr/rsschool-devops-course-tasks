terraform {
  required_version = ">= 1.0"
}

# test S3 bucket infrastructure:
module "test_bucket" {
  source     = "./modules/s3_bucket"
  bucket_name = "test-bucket-${random_id.this.hex}"
  tags = {
    Environment = "Test"
  }
}

resource "random_id" "this" {
  byte_length = 8
}

