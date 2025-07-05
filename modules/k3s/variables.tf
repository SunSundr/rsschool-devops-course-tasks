variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for K3s nodes"
  type        = list(string)
}

variable "k3s_sg_id" {
  description = "ID of K3s security group"
  type        = string
}

variable "key_name" {
  description = "Name of SSH key pair"
  type        = string
}

variable "instance_type" {
  description = "Instance type for K3s nodes"
  type        = string
  default     = "t3.micro"
}
