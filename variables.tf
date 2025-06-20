variable "github_repo" {
  description = "GitHub repository path in format 'username/repo'"
  type        = string
  default     = "SunSundr/rsschool-devops-course-tasks"
}

variable "terraform_state_S3_bucket" {
  description = "Terraform state S3 bucket name"
  type        = string
  default     = "rss-devops-terraform-state"
}