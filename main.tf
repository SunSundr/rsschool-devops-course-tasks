terraform {
  required_version = ">= 1.0"
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  project  = var.project
}

# First create the subnets without NAT routing
module "networking" {
  source = "./modules/networking"

  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  project                = var.project
  igw_id                 = module.vpc.igw_id
  default_route_table_id = module.vpc.default_route_table_id
  create_nat_route       = false # Don't create NAT route yet
}

module "security" {
  source = "./modules/security"

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  project            = var.project
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
}

module "compute" {
  source = "./modules/compute"

  project               = var.project
  public_subnet_id      = module.networking.public_subnet_ids[0]
  bastion_sg_id         = module.security.bastion_sg_id
  nat_sg_id             = module.security.nat_sg_id
  bastion_instance_type = var.bastion_instance_type
  nat_instance_type     = var.nat_instance_type
}

# Now create the NAT route
resource "aws_route" "private_nat" {
  route_table_id         = module.networking.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.compute.nat_instance_eni_id
  # nat_gateway_id         = module.networking.nat_gateway_id
}



# TEST INFRASTRUCTURE

# test S3 bucket infrastructure:
module "test_bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = "test-bucket-${random_id.this.hex}"
  tags = {
    Environment = "Test"
  }
}

resource "random_id" "this" {
  byte_length = 8
}

#---------------------------------------------------------
# K3s Cluster
variable "enable_k3s_cluster" {
  description = "Whether to create K3s cluster"
  type        = bool
  default     = false
}

module "k3s" {
  source = "./modules/k3s"
  count  = var.enable_k3s_cluster ? 1 : 0

  project            = var.project
  private_subnet_ids = module.networking.private_subnet_ids
  k3s_sg_id          = module.security.k3s_sg_id
  key_name           = module.compute.key_name
  instance_type      = "t3.micro"
}

#---------------------------------------------------------
# Add test instances (temp)
variable "enable_test_instances" {
  description = "Whether to create test instances"
  type        = bool
  default     = false
}

module "tests" {
  source = "./modules/tests"
  count  = var.enable_test_instances ? 1 : 0

  project            = var.project
  public_subnet_id   = module.networking.public_subnet_ids[0]
  private_subnet_ids = module.networking.private_subnet_ids
  public_sg_id       = module.security.public_sg_id
  private_sg_id      = module.security.private_sg_id
  key_name           = module.compute.key_name
}

output "test_public_ip" {
  description = "Public IP of test public instance"
  value       = var.enable_test_instances ? module.tests[0].test_public_ip : null
}

output "test_private_az1_ip" {
  description = "Private IP of test private app server in AZ1"
  value       = var.enable_test_instances ? module.tests[0].test_private_az1_ip : null
}

output "test_private_az2_ip" {
  description = "Private IP of test private db server in AZ2"
  value       = var.enable_test_instances ? module.tests[0].test_private_az2_ip : null
}