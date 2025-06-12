terraform {
  backend "s3" {
    bucket         = "rss-devops-terraform-state"
    key            = "global/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = ""
  }
}
