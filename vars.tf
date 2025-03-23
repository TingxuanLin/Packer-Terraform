variable "REGION" {
  default = "us-east-1"
}

variable "ZONE1" {
  default = "us-east-1a"
}

variable "ZONE2" {
  default = "us-east-1b"
}

variable "ZONE3" {
  default = "us-east-1c"
}

variable "AMIS" {
  default = {
    us-east-1 = "CUSTOM AMI"
  }
}

variable "USER" {
  default = "ec2-user"
}

variable "MYIP" {
  default = "MY IP"
}