terraform {
  required_version = ">= 1.0"
}

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

#--------------------------------
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  project  = var.project
}

# First create the subnets without NAT routing
module "networking" {
  source = "./modules/networking"

  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  project              = var.project
  igw_id               = module.vpc.igw_id
  create_nat_route     = false # Don't create NAT route yet
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
}
