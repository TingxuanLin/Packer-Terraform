# Security group for the bastion host in the public subnet
resource "aws_security_group" "bastion_sg" {
  name        = "allow_ssh_bastion"
  description = "Security group for bastion host allowing SSH from internet"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "Bastion_SG"
  }
}

# Allow SSH from your IP to the bastion host
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_ingress" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "${var.MYIP}/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Allow all outbound traffic from the bastion host
resource "aws_vpc_security_group_egress_rule" "bastion_egress" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Security group for the private instances
resource "aws_security_group" "private_sg" {
  name        = "allow_ssh_private"
  description = "Security group for private instances allowing SSH only from bastion"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "Private_Instances_SG"
  }
}

# Allow SSH only from the bastion security group to private instances
resource "aws_vpc_security_group_ingress_rule" "private_ssh_from_bastion" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

# Allow all outbound traffic from private instances
resource "aws_vpc_security_group_egress_rule" "private_egress" {
  security_group_id = aws_security_group.private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}