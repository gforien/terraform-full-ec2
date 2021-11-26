terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
  profile = "default"                                       # optionnal
}


#-----------------------------------------------------------------------------------------
# 1. VPC - IG - open route - SG
#-----------------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
# Route - solution 1
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
# Route - solution 2
# resource "aws_route" "main" {
#   route_table_id = aws_vpc.main.main_route_table_id
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id = aws_internet_gateway.main.id
# }
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id
  ingress {
    description = "HTTP"                                    # optionnal
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"                                     # optionnal
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#-----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# 2. Subnet - NIC
#-----------------------------------------------------------------------------------------
resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "eu-west-1c"                          # optionnal

  # Subnets have to be allowed to automatically map public IP addresses for worker nodes
  map_public_ip_on_launch = true                            # optionnal but necessary
}
resource "aws_network_interface" "main" {
  subnet_id       = aws_subnet.main.id
  security_groups = [aws_security_group.main.id]            # optionnal but necessary
}
# Route - solution 1
resource "aws_route_table_association" "main" {
  route_table_id = aws_route_table.main.id
  subnet_id      = aws_subnet.main.id
}
# Route - solution 2
# <empty> (no need for route_table_association)
#-----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# 3. Instance
#-----------------------------------------------------------------------------------------
# (Note that variables should be declared in file variables.tf)
variable "key_name" {
  type        = string
  description = "A pre-existing SSH key for EC2 instances"
  default     = ""                                            # default can be empty
}
resource "aws_instance" "main" {
  ami                    = "ami-0ed961fa828560210"
  instance_type          = "t2.micro"                         # optionnal
  key_name               = var.key_name                       # optionnal
  subnet_id              = aws_subnet.main.id                 # optionnal but necessary
  vpc_security_group_ids = [aws_security_group.main.id]       # optionnal but necessary
  # we don't do that
  # network_interface {
  #   device_index = 0
  #   network_interface_id = aws_network_interface.main.id
  # }
  user_data              = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install -y nginx1
    sudo service nginx start
    echo '<h1>gforien.com</h1>' > /usr/share/nginx/html
  EOF
}
#-----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# 4. DNS
#-----------------------------------------------------------------------------------------
# DNS zone - solution 1
# (Note that variables should be declared in file variables.tf)
variable "zone_id" {
  type        = string
  description = "A pre-existing DNS zone in Route53"
}
variable "domain" {
  type        = string
  description = "The domain name to be created"
  default     = "test.gforien.com"
}
# DNS zone - solution 2
# Declare a resource block
# resource "aws_route53_zone" "primary" {
#   name = "example.com"
# }
# Then import the pre-existing zone
# > terraform import aws_route53_zone.myzone Z1D633PJN98FT9
resource "aws_route53_record" "main" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "A"
  ttl     = "300"
  records = [aws_instance.main.public_ip]
}
#-----------------------------------------------------------------------------------------
