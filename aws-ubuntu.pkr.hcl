packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_access_key" {
  type    = string
  default = env("AWS_ACCESS_KEY_ID")
}

variable "aws_secret_key" {
  type    = string
  default = env("AWS_SECRET_ACCESS_KEY")
}

variable "aws_session_token" {
    type  = string
    default = env("AWS_SESSION_TOKEN")
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_public_key" {
  type    = string
  default = env("SSH_PUBLIC_KEY")
}

source "amazon-ebs" "amazon_linux" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  token         = var.aws_session_token
  region        = var.region
  instance_type = "t2.micro"
  ssh_username  = "ec2-user"
  
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-2.*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  
  ami_name        = "custom-amazon-linux-docker-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  ami_description = "Custom Amazon Linux AMI with Docker and SSH key pre-installed"
}

build {
  sources = ["source.amazon-ebs.amazon_linux"]

  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      "sudo amazon-linux-extras install docker -y",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -a -G docker ec2-user",
      "echo 'Docker installation completed.'"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Setting up SSH access...'",
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh",
      "echo '${var.ssh_public_key}' >> ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys",
      "echo 'SSH setup completed.'"
    ]
  }
}