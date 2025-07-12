# Security group for bastion host
resource "aws_security_group" "bastion" {
  name        = "${var.project}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to IP in production
  }

  # Port 8080 for Flask app port-forward access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Public access to Flask app via port-forward"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-bastion-sg"
  }
}

# Security group for NAT instance
resource "aws_security_group" "nat" {
  name        = "${var.project}-nat-sg"
  description = "Security group for NAT instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-nat-sg"
  }
}

# Security group for public instances
resource "aws_security_group" "public" {
  name        = "${var.project}-public-sg"
  description = "Security group for public instances"
  vpc_id      = var.vpc_id

  # Allow all traffic (temp)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"] # Restrict to IP in production
  # }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = "${var.project}-public-sg"
  }
}


# Security group for private instances
resource "aws_security_group" "private" {
  name        = "${var.project}-private-sg"
  description = "Security group for private instances"
  vpc_id      = var.vpc_id

  # Allow all traffic from bastion
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.bastion.id]
  }

  # Allow all traffic from NAT instance
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.nat.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-private-sg"
  }
}

# Network ACL for public subnets
resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project}-public-nacl"
  }
}

# Network ACL for private subnets
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  ingress {
    protocol = "-1"
    rule_no  = 100
    action   = "allow"
    # cidr_block = var.vpc_cidr # This only allows VPC traffic!
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project}-private-nacl"
  }
}

# Security group for K3s cluster
resource "aws_security_group" "k3s" {
  name        = "${var.project}-k3s-sg"
  description = "Security group for K3s cluster"
  vpc_id      = var.vpc_id

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # K3s API server - ADD ACCESS FROM BASTION
  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id] # Allow bastion access
  }

  # K3s API server - between nodes
  ingress {
    from_port = 6443
    to_port   = 6443
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8472
    to_port   = 8472
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 10250
    to_port   = 10250
    protocol  = "tcp"
    self      = true
  }

  # NodePort range - internal cluster communication
  ingress {
    from_port = 30000
    to_port   = 32767
    protocol  = "tcp"
    self      = true
  }

  # NodePort range - public access for Flask app (fixed port)
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Public access to Flask app via NodePort"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-k3s-sg"
  }
}
