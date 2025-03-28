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

source "amazon-ebs" "ubuntu" {
  access_key    = var.aws_access_key
  secret_key    = var.aws_secret_key
  token         = var.aws_session_token
  region        = var.region
  instance_type = "t2.micro"
  ssh_username  = "ubuntu"
  
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical's owner ID
  }
  
  ami_name        = "custom-ubuntu-docker-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  ami_description = "Custom Ubuntu 22.04 AMI with Docker and SSH key pre-installed"
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

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      # Add retry logic for apt-get update
      "for i in {1..5}; do sudo apt-get update && break || { echo 'apt-get update failed, retrying in 30 seconds...'; sleep 30; }; done",
      # Add retry logic for package installation
      "for i in {1..3}; do sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common && break || { echo 'Package installation failed, retrying in 30 seconds...'; sleep 30; }; done",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      # Add retry logic for second apt-get update
      "for i in {1..5}; do sudo apt-get update && break || { echo 'apt-get update failed, retrying in 30 seconds...'; sleep 30; }; done",
      # Add retry logic for docker installation
      "for i in {1..3}; do sudo apt-get install -y docker-ce docker-ce-cli containerd.io && break || { echo 'Docker installation failed, retrying in 30 seconds...'; sleep 30; }; done",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -a -G docker ubuntu",
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