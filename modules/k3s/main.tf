# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.k3s_sg_id]
  key_name               = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
              # Wait for k3s to be ready
              sleep 30
              # Get the node token for worker nodes
              cp /var/lib/rancher/k3s/server/node-token /home/ubuntu/node-token
              chown ubuntu:ubuntu /home/ubuntu/node-token
              # Copy kubeconfig for ubuntu user
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown ubuntu:ubuntu /home/ubuntu/.kube/config
              EOF

  tags = {
    Name = "${var.project}-k3s-master"
    Role = "k3s-master"
  }
}

# K3s Worker Node
resource "aws_instance" "k3s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.k3s_sg_id]
  key_name               = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              # Wait for master to be ready
              sleep 60
              # Join the cluster
              curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@${aws_instance.k3s_master.private_ip} 'cat /home/ubuntu/node-token') sh -
              EOF

  depends_on = [aws_instance.k3s_master]

  tags = {
    Name = "${var.project}-k3s-worker"
    Role = "k3s-worker"
  }
}
