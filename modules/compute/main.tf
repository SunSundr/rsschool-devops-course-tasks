# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# # SSH key pair
# resource "aws_key_pair" "main" {
#   key_name   = "${var.project}-key"
#   public_key = file("~/.ssh/id_rsa.pub") # Replace with your public key path
# }

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
              sysctl -w net.ipv4.ip_forward=1
              /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
              EOF

  tags = {
    Name = "${var.project}-nat"
  }
}
