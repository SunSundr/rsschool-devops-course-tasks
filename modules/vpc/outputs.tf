output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "default_route_table_id" {
  description = "ID of the default route table"
  value       = aws_vpc.main.default_route_table_id
}
