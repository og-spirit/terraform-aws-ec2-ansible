terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5.0"
    }
  }
}

variable "awsprops" {
  type = map(string)
  default = {
    region       = "ap-southeast-2"
    vpc          = "vpc-b18586d5"
    ami          = "ami-0e040c48614ad1327"
    itype        = "t2.micro"
    subnet       = "subnet-1b01d67c"
    publicip     = true
    keyname      = "devops"
    secgroupname = "Wildseed-Sec-Group"
  }
}

locals {
  ssh_user         = "ubuntu"
  key_name         = "devops"
  private_key_path = "~/.ssh_pem/devops.pem"
}

provider "aws" {
  region = lookup(var.awsprops, "region")
}

resource "aws_security_group" "project-wildseed-sg" {
  name        = lookup(var.awsprops, "secgroupname")
  description = lookup(var.awsprops, "secgroupname")
  vpc_id      = lookup(var.awsprops, "vpc")

  // To Allow SSH Transport
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  // To Allow Port 80 Transport
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  // To Allow Port 443 Transport
  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "project-wildseed-ec2" {
  ami                         = lookup(var.awsprops, "ami")
  instance_type               = lookup(var.awsprops, "itype")
  subnet_id                   = lookup(var.awsprops, "subnet") #FFXsubnet2
  associate_public_ip_address = lookup(var.awsprops, "publicip")
  key_name                    = lookup(var.awsprops, "keyname")


  vpc_security_group_ids = [
    aws_security_group.project-wildseed-sg.id
  ]
  root_block_device {
    delete_on_termination = true
    // iops                  = 150
    volume_size = 50
    volume_type = "gp2"
  }
  tags = {
    Name        = "Wildseed_SERVER01"
    Environment = "DEV"
    OS          = "UBUNTU"
    Managed     = "Wildseed"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Wait until SSH is ready'"
    ]

    connection {
      type        = "ssh"
      user        = local.ssh_user
      private_key = file(local.private_key_path)
      host        = aws_instance.project-wildseed-ec2.public_ip
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook  -i ${aws_instance.project-wildseed-ec2.public_ip}, --private-key ${local.private_key_path} services.yml"
  }

  depends_on = [aws_security_group.project-wildseed-sg]
}

output "ec2instance" {
  value = aws_instance.project-wildseed-ec2.public_ip
}