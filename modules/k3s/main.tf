# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.amazon_linux.id
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
              yum update -y
              
              # Install K3s master
              curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true sh -s - --write-kubeconfig-mode 644
              
              # Wait for K3s to be ready
              until systemctl is-active --quiet k3s; do
                sleep 5
              done
              
              # Set up files for ec2-user
              cp /var/lib/rancher/k3s/server/node-token /home/ec2-user/node-token
              chown ec2-user:ec2-user /home/ec2-user/node-token
              chmod 600 /home/ec2-user/node-token
              
              # Copy kubeconfig for ec2-user
              mkdir -p /home/ec2-user/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
              chown ec2-user:ec2-user /home/ec2-user/.kube/config
              chmod 600 /home/ec2-user/.kube/config
              EOF

  tags = {
    Name = "${var.project}-k3s-master"
    Role = "k3s-master"
  }
}

# K3s Worker Node
resource "aws_instance" "k3s_worker" {
  ami                    = data.aws_ami.amazon_linux.id
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
              yum update -y
              
              # Log everything for debugging
              exec > >(tee /var/log/k3s-worker-setup.log) 2>&1
              
              echo "Starting K3s worker setup..."
              
              # Wait longer for master to be fully ready
              echo "Waiting for master to be ready..."
              for i in {1..30}; do
                if curl -k https://${aws_instance.k3s_master.private_ip}:6443/ping >/dev/null 2>&1; then
                  echo "Master API is ready"
                  break
                fi
                echo "Attempt $i: Master not ready, waiting 20 seconds..."
                sleep 20
              done
              
              # Get node token with retries
              echo "Getting node token from master..."
              for i in {1..20}; do
                NODE_TOKEN=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null ec2-user@${aws_instance.k3s_master.private_ip} 'cat /home/ec2-user/node-token' 2>/dev/null)
                if [ ! -z "$NODE_TOKEN" ]; then
                  echo "Successfully got node token"
                  break
                fi
                echo "Attempt $i: Failed to get token, waiting 15 seconds..."
                sleep 15
              done
              
              if [ -z "$NODE_TOKEN" ]; then
                echo "Failed to get node token after all attempts"
                exit 1
              fi
              
              # Install K3s worker
              echo "Installing K3s worker..."
              curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_SELINUX_RPM=true K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN="$NODE_TOKEN" sh -
              
              # Wait for service to be active
              echo "Waiting for K3s agent to be active..."
              until systemctl is-active --quiet k3s-agent; do
                echo "K3s agent not active yet, waiting..."
                sleep 10
              done
              
              echo "K3s worker setup completed successfully!"
              systemctl status k3s-agent --no-pager
              EOF

  depends_on = [aws_instance.k3s_master]

  tags = {
    Name = "${var.project}-k3s-worker"
    Role = "k3s-worker"
  }
}
