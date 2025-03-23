# Bastion host in public subnet
resource "aws_instance" "bastion_host" {
  ami                         = var.AMIS[var.REGION]
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "Bastion_Host"
  }
}

# Private instances in private subnets
resource "aws_instance" "private_instances" {
  count         = 6
  ami           = var.AMIS[var.REGION]
  instance_type = "t2.micro"
  subnet_id = element(
    [
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id,
      aws_subnet.private_subnet_3.id,
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id,
      aws_subnet.private_subnet_3.id
    ],
    count.index
  )
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  tags = {
    Name = "Private_Instance_${count.index + 1}"
  }
}

# Outputs
output "BastionPublicIP" {
  value = aws_instance.bastion_host.public_ip
}

output "PrivateIPs" {
  value = aws_instance.private_instances[*].private_ip
}