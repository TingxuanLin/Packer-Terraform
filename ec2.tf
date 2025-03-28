# Ansible Controller (former Bastion host) in public subnet
resource "aws_instance" "ansible_controller" {
  ami                         = var.AMIS[var.REGION]["ubuntu"]
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "Ansible_Controller"
  }
}

# Private instances in private subnets (3 Ubuntu and 3 Amazon Linux)
resource "aws_instance" "private_instances" {
  count         = 6
  ami           = count.index < 3 ? var.AMIS[var.REGION]["ubuntu"] : var.AMIS[var.REGION]["amazon"]
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
    OS   = count.index < 3 ? "ubuntu" : "amazon"
  }
}

# Outputs
output "AnsibleControllerPublicIP" {
  value = aws_instance.ansible_controller.public_ip
}

output "PrivateIPs" {
  value = aws_instance.private_instances[*].private_ip
}

output "InstanceOS" {
  value = [for instance in aws_instance.private_instances : instance.tags.OS]
}