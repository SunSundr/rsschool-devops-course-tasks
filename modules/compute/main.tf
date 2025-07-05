# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Generate SSH key pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/keys/${var.project}-key.pem"
  file_permission = "0600"
}

# Create AWS key pair
resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# Bastion host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = aws_key_pair.main.key_name

  # enable IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/
              # Create .kube directory for ec2-user
              mkdir -p /home/ec2-user/.kube
              chown ec2-user:ec2-user /home/ec2-user/.kube
              EOF

  tags = {
    Name = "${var.project}-bastion"
  }
}

# NAT instance
resource "aws_instance" "nat" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.nat_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.nat_sg_id]
  source_dest_check      = false # Required for NAT functionality
  key_name               = aws_key_pair.main.key_name

  user_data = <<-EOF
              #!/bin/bash
              # Enable IP forwarding permanently
              echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
              sysctl -w net.ipv4.ip_forward=1
              
              # Get the primary interface name (works on both eth0 and ens5)
              INTERFACE=$(ip route | grep default | awk '{print $5}')
              
              # Set up NAT with iptables
              /sbin/iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
              /sbin/iptables -A FORWARD -i $INTERFACE -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
              /sbin/iptables -A FORWARD -i $INTERFACE -o $INTERFACE -j ACCEPT
              
              # Save iptables rules permanently
              systemctl enable iptables
              systemctl start iptables
              iptables-save > /etc/sysconfig/iptables
              
              # Enable iptables service to start on boot
              /sbin/chkconfig iptables on
              
              # Update system
              # yum update -y
              EOF

  # enable IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project}-nat"
  }
}
