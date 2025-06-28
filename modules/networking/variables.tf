variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "project" {
  description = "Project name for resource tagging"
  type        = string
}

variable "nat_instance_id" {
  description = "ID of the NAT instance"
  type        = string
  default     = null
}

variable "nat_instance_eni_id" {
  description = "Network Interface ID of the NAT instance"
  type        = string
  default     = null
}

variable "igw_id" {
  description = "ID of the Internet Gateway"
  type        = string
}

variable "create_nat_route" {
  description = "Whether to create NAT route"
  type        = bool
  default     = false
}

variable "default_route_table_id" {
  description = "ID of the default route table"
  type        = string
}
