terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
  }
  required_version = ">= 1.7.0"
}

locals {
  ssh_private_key = (
    var.private_key != null && var.private_key != ""
  ) ? var.private_key : (
    var.private_key_path != null && var.private_key_path != ""
  ) ? file(var.private_key_path) : ""
}

provider "aws" {
  region = var.region
}

# -------------------------------
# VPC, Subnet, IG, Route Table
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "mediplus-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = { Name = "public-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "internet-gateway" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------
# Security Groups
# -------------------------------
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "web-sg" }
}

resource "aws_security_group" "proxy_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "proxy-sg" }
}

# -------------------------------
# 180-Second Delay
# -------------------------------
resource "time_sleep" "wait_180_seconds" {
  create_duration = "180s"
}

# -------------------------------
# EC2 Instances
# -------------------------------
resource "aws_instance" "web_server" {
  lifecycle {
    precondition {
      condition     = local.ssh_private_key != ""
      error_message = "Provide TF_VAR_private_key (PEM content) or a valid private_key_path that exists."
    }
  }
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags                   = { Name = "web-server" }

  # Connection block at resource level
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = local.ssh_private_key
    host        = self.public_ip
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_and_deploy_web.sh"
    destination = "/home/ubuntu/install_and_deploy_web.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_and_deploy_web.sh",
      "sudo /home/ubuntu/install_and_deploy_web.sh ${var.domain_name}"
    ]
  }
}

resource "aws_instance" "reverse_proxy" {
  lifecycle {
    precondition {
      condition     = local.ssh_private_key != ""
      error_message = "Provide TF_VAR_private_key (PEM content) or a valid private_key_path that exists."
    }
  }
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]
  tags                   = { Name = "reverse-proxy" }

  depends_on = [time_sleep.wait_180_seconds]

  # Connection block at resource level
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = local.ssh_private_key
    host        = self.public_ip
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_and_configure_proxy.sh"
    destination = "/home/ubuntu/install_and_configure_proxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_and_configure_proxy.sh",
      "sudo /home/ubuntu/install_and_configure_proxy.sh ${aws_instance.web_server.public_ip} ${var.domain_name} ${var.email}"
    ]
  }
}

