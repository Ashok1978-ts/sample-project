#!/bin/bash

PROJECT="terraform-aws-infra"

mkdir -p $PROJECT/modules/{vpc,security_group,ec2}

cd $PROJECT

# Root provider
cat <<EOF > provider.tf
provider "aws" {
  region = var.aws_region
}
EOF

# Root variables
cat <<EOF > variables.tf
variable "aws_region" {
  default = "us-east-1"
}
EOF

# Root main
cat <<EOF > main.tf
module "vpc" {
  source = "./modules/vpc"
}

module "security_group" {
  source = "./modules/security_group"
  vpc_id = module.vpc.vpc_id
}

module "ec2" {
  source          = "./modules/ec2"
  subnet_id       = module.vpc.public_subnet_id
  security_group  = module.security_group.sg_id
}
EOF

cat <<EOF > outputs.tf
output "instance_public_ip" {
  value = module.ec2.instance_public_ip
}
EOF

###################################
# VPC MODULE
###################################

cat <<EOF > modules/vpc/variables.tf
variable "cidr_block" {
  default = "10.0.0.0/16"
}
EOF

cat <<EOF > modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
EOF

cat <<EOF > modules/vpc/outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}
EOF

###################################
# SECURITY GROUP MODULE
###################################

cat <<EOF > modules/security_group/variables.tf
variable "vpc_id" {}
EOF

cat <<EOF > modules/security_group/main.tf
resource "aws_security_group" "sg" {
  name   = "allow_ssh"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
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
EOF

cat <<EOF > modules/security_group/outputs.tf
output "sg_id" {
  value = aws_security_group.sg.id
}
EOF

###################################
# EC2 MODULE
###################################

cat <<EOF > modules/ec2/variables.tf
variable "subnet_id" {}
variable "security_group" {}
EOF

cat <<EOF > modules/ec2/main.tf
resource "aws_instance" "web" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id
  vpc_security_group_ids = [var.security_group]

  tags = {
    Name = "Terraform-EC2"
  }
}
EOF

cat <<EOF > modules/ec2/outputs.tf
output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
EOF

echo "Terraform project structure created successfully!"

