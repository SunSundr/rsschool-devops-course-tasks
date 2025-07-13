terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Provider for us-east-1 (required for CloudFront SSL certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}