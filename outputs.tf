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

output "k3s_master_ip" {
  description = "Private IP of K3s master node"
  value       = var.enable_k3s_cluster ? module.k3s[0].k3s_master_ip : null
}

output "k3s_worker_ip" {
  description = "Private IP of K3s worker node"
  value       = var.enable_k3s_cluster ? module.k3s[0].k3s_worker_ip : null
}
