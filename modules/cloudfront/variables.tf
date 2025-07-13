variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "bastion_public_ip" {
  description = "Public IP of bastion host"
  type        = string
}

variable "enable_cloudfront" {
  description = "Whether to create CloudFront resources"
  type        = bool
  default     = false
}