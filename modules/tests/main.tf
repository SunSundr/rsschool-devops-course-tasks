data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Test public instance
resource "aws_instance" "test_public" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.public_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from public instance" > /home/ec2-user/test.txt
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Public Instance</h1>" > /var/www/html/index.html
              EOF

  # enable IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project}-public-test-server"
  }
}

# # Test private instance
# resource "aws_instance" "test_private" {
#   ami                    = data.aws_ami.amazon_linux.id
#   instance_type          = "t3.micro"
#   subnet_id              = var.private_subnet_id
#   vpc_security_group_ids = [var.private_sg_id]
#   key_name               = var.key_name
  
#   user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello from private instance" > /home/ec2-user/test.txt
#               yum update -y
#               EOF

#   tags = {
#     Name = "${var.project}-test-private"
#   }
# }

# Test private instance in first AZ
resource "aws_instance" "test_private_az1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.private_sg_id]
  key_name               = var.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from private instance in AZ1" > /home/ec2-user/test.txt
              yum update -y
              EOF

  tags = {
    Name = "${var.project}-private-test-server-az1"
  }
}

# Test private instance in second AZ
resource "aws_instance" "test_private_az2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.private_sg_id]
  key_name               = var.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from private instance in AZ2" > /home/ec2-user/test.txt
              yum update -y
              EOF

  tags = {
    Name = "${var.project}-private-test-server-az2"
  }
}