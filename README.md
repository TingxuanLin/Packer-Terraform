# Packer-Terraform

chmod 600 private-key.pem
ssh-keygen -y -f /path/to/your/private-key.pem > publickey.pub

export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
export SSH_PUBLIC_KEY=$(cat publickey.pub)

packer init .

packer build .

abstract new AMI from output
in vars.tf file upate MYIP AMIS

terraform init
terraform validate
terraform fmt
terraform apply

terraform output BastionPublicIP
terraform output PrivateIPs

ssh-add /path/to/your/privatekey.pem

ssh ec2-user@<bastion-public-ip>

ssh ec2-user@<private-instance-ip>
