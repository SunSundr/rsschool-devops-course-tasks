variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of public subnet for test instance"
  type        = string
}

# variable "private_subnet_id" {
#   description = "ID of private subnet for test instance"
#   type        = string
# }

variable "private_subnet_ids" {
  description = "IDs of private subnets for test instances"
  type        = list(string)
}

variable "public_sg_id" {
  description = "ID of public security group"
  type        = string
}

variable "private_sg_id" {
  description = "ID of private security group"
  type        = string
}

variable "key_name" {
  description = "Name of SSH key pair"
  type        = string
}
