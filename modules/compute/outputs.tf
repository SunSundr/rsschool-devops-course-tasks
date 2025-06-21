output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "nat_public_ip" {
  description = "Public IP of NAT instance"
  value       = aws_instance.nat.public_ip
}

output "nat_instance_id" {
  description = "ID of NAT instance"
  value       = aws_instance.nat.id
}

output "nat_instance_eni_id" {
  description = "Network Interface ID of NAT instance"
  value       = aws_instance.nat.primary_network_interface_id
}
