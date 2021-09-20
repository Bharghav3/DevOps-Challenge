**Steps to Provision the Application:**

**To build application image and running application (Locally):**

a)	I have cloned the Git repository into my Local,
      •	git clone https://github.com/iPriceGroup/DevOps-Challenge.git

b)	Then ran the Docker compose command,
      •	docker-compose up -d
    This command created the image and the deployed the containers into my local machine.

**How to provision infrastructure with Terraform:**

I have used the below main.tf file to provision our infrastructure with Terraform.

Prerequisites:
•	an AWS account
•	a SSH key-pair in AWS
•	AWS access tokens set in the environment as AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY


            # AWS resources are created in Singapore.
            provider "aws" {
              access_key = "AKIAQGC4I5PVYM6WNQJF"
              secret_key = "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"
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
            #The EC2 instance should accessible only through the below IP and Should be able to SSH into the EC2 instance.

            module "dev_ssh_sg" {
              source = "terraform-aws-modules/security-group/aws"

              name        = "dev_ssh_sg"
              description = "Security group for dev_ssh_sg"
              vpc_id      = data.aws_vpc.default.id
              ingress_cidr_blocks = ["205.175.212.203/32"]
              ingress_rules       = ["ssh-tcp"]
            }

            # Application can be reached on port 80
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
                sudo su -
                git clone https://github.com/Bharghav3/DevOps-Challenge.git
                cd DevOps-Challenge
                docker-compose up -d
              EOF

              vpc_security_group_ids = [
                #module.ec2_sg.this_security_group_id,
                #module.dev_ssh_sg.this_security_group_id
                "sg-0df764bfa447e8603",
                "sg-0d22cee8d39ecf75a"
              ]

              tags = {
                name = "iPrice"
              }

              key_name                = "myKeyPair"
              monitoring              = true
              disable_api_termination = false
            }

**Changes you performed to the provided code.**

a)	In Dockerfile,

      1)	“\” Backward slash missing in Install Dependencies 
                  # Install dependencies
                    RUN apt-get update && apt-get install -y \
                          build-essential \
                          libpng-dev \
                          libjpeg62-turbo-dev \
                          libfreetype6-dev \
                          locales **\**
                          zip \

      2)	Replaced “DO” with “RUN” in # Add user for laravel application
                    # Add user for laravel application
                    RUN groupadd -g 1000 www
                    **RUN** useradd -u 1000 -ms /bin/bash -g www www

      3)	Changed the user from www2 to www in Change current user field.

                    # Change current user to www
                    USER **www**

b)	In Docker-Compse.yml file,

      1)	Changed image name from ngnx to nginx.
                  #Nginx Service
                    webserver:
                      image: **nginx**:alpine

      2)	Changed port from 8 to 80.
                   ports:
                  - "**80**:80"
                  - "443:443"

      3)	Changed network of Web Container from server-network to app-network
                  networks:
                    - **app**-network

