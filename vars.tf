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
    us-east-1 = {
      "amazon" = "amz-ami"
      "ubuntu" = "ubuntu-ami"
    }
  }
}

variable "USER" {
  default = "ubuntu"
}

variable "MYIP" {
  default = "my_ip"
}
