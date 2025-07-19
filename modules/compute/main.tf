# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Simple directory-based key management
locals {
  keys_dir        = "${path.module}/keys"
  public_key_path = "${local.keys_dir}/${var.project}-key.pem.pub"
  keys_exist      = can(fileset(local.keys_dir, "*")) && fileexists(local.public_key_path)
  # Skip compute resources in GitHub Actions environment
  is_github_actions = can(regex("runner", path.cwd))
  should_create     = local.keys_exist && !local.is_github_actions
}

resource "null_resource" "setup_keys" {
  count = local.should_create ? 0 : 1

  triggers = {
    keys_dir = local.keys_dir
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${local.keys_dir}" 2>/dev/null || true
      ssh-keygen -t rsa -b 4096 -m PEM -f "${local.keys_dir}/${var.project}-key.pem" -N ""
      if [ "$(uname -s)" != "Windows_NT" ]; then
        chmod 600 "${local.keys_dir}/${var.project}-key.pem"
        chmod 644 "${local.keys_dir}/${var.project}-key.pem.pub"
      fi
    EOT

    interpreter = ["/bin/sh", "-c"]
  }
}

# Read existing public key (only if it exists)
data "local_file" "public_key" {
  count      = local.should_create ? 1 : 0
  filename   = local.public_key_path
  depends_on = [null_resource.setup_keys]
}

# Create AWS key pair (only if keys exist locally)
resource "aws_key_pair" "main" {
  count      = local.should_create ? 1 : 0
  key_name   = "${var.project}-key"
  public_key = data.local_file.public_key[0].content
}

# Bastion host (only if keys exist)
resource "aws_instance" "bastion" {
  count                  = local.should_create ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = aws_key_pair.main[0].key_name

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

# NAT instance (only if keys exist)
resource "aws_instance" "nat" {
  count                  = local.should_create ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.nat_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.nat_sg_id]
  source_dest_check      = false # Required for NAT functionality
  key_name               = aws_key_pair.main[0].key_name

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
