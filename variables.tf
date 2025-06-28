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

#----------------------------------
variable "region" {
  description = "AWS region"
  default     = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  default     = "t3.micro"
}

variable "nat_instance_type" {
  description = "Instance type for NAT instance"
  default     = "t3.micro"
}

variable "project" {
  description = "Project name for resource tagging"
  default     = "rss"
}
