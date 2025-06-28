output "bastion_sg_id" {
  description = "ID of bastion security group"
  value       = aws_security_group.bastion.id
}

output "nat_sg_id" {
  description = "ID of NAT security group"
  value       = aws_security_group.nat.id
}

output "private_sg_id" {
  description = "ID of private security group"
  value       = aws_security_group.private.id
}

output "public_sg_id" {
  description = "ID of public security group"
  value       = aws_security_group.public.id
}
