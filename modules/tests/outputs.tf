output "test_public_ip" {
  description = "Public IP of test public instance"
  value       = aws_instance.test_public.public_ip
}

# output "test_private_ip" {
#   description = "Private IP of test private instance"
#   value       = aws_instance.test_private.private_ip
# }

output "test_private_az1_ip" {
  description = "Private IP of test private instance in AZ1"
  value       = aws_instance.test_private_az1.private_ip
}

output "test_private_az2_ip" {
  description = "Private IP of test private instance in AZ2"
  value       = aws_instance.test_private_az2.private_ip
}