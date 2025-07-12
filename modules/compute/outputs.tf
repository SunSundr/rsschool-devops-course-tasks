output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = length(aws_instance.bastion) > 0 ? aws_instance.bastion[0].public_ip : null
}

output "nat_public_ip" {
  description = "Public IP of NAT instance"
  value       = length(aws_instance.nat) > 0 ? aws_instance.nat[0].public_ip : null
}

output "nat_instance_id" {
  description = "ID of NAT instance"
  value       = length(aws_instance.nat) > 0 ? aws_instance.nat[0].id : null
}

output "nat_instance_eni_id" {
  description = "Network Interface ID of NAT instance"
  value       = length(aws_instance.nat) > 0 ? aws_instance.nat[0].primary_network_interface_id : null
}

output "key_name" {
  description = "Name of the SSH key pair"
  value       = length(aws_key_pair.main) > 0 ? aws_key_pair.main[0].key_name : null
}
