output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

#----------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.compute.bastion_public_ip
}

output "nat_public_ip" {
  description = "Public IP of NAT instance"
  value       = module.compute.nat_public_ip
}
