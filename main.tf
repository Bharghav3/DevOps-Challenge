provider "aws" {
  access_key = ""
  secret_key = ""
  region = "ap-southeast-1"
}

terraform {
  required_version = ">= 0.12.0"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

### EC2

module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "dev_ssh_sg"
  description = "Security group for dev_ssh_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "ec2_role_iprice" {
  name = "ec2_role_iprice"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    project = "iPrice"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo yum install git -y
    sudo git clone https://github.com/iPriceGroup/DevOps-Challenge.git
    sudo cd DevOps-Challenge
    sudo docker-compose up -d
  EOF

  vpc_security_group_ids = [
    #module.ec2_sg.this_security_group_id,
    #module.dev_ssh_sg.this_security_group_id
    "sg-023c1261b7d2140a0",
    "sg-0c07bcef029c26327"
  ]

  tags = {
    name = "iPrice"
  }

  key_name                = "myKeyPair"
  monitoring              = true
  disable_api_termination = false
}
