output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_route_table_id" {
  description = "ID of private route table"
  value       = aws_route_table.private.id
}

output "public_route_table_id" {
  description = "ID of the public (default) route table"
  value       = aws_default_route_table.public.id
}

# output "nat_gateway_id" {
#   description = "ID of NAT Gateway"
#   value       = aws_nat_gateway.main.id
# }
