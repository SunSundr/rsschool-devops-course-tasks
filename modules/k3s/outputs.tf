output "k3s_master_ip" {
  description = "Private IP of K3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_worker_ip" {
  description = "Private IP of K3s worker node"
  value       = aws_instance.k3s_worker.private_ip
}

output "k3s_master_id" {
  description = "Instance ID of K3s master node"
  value       = aws_instance.k3s_master.id
}
