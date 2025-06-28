variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of public subnet for instances"
  type        = string
}

variable "bastion_sg_id" {
  description = "ID of bastion security group"
  type        = string
}

variable "nat_sg_id" {
  description = "ID of NAT security group"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
}

variable "nat_instance_type" {
  description = "Instance type for NAT instance"
  type        = string
}
