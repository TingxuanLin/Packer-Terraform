# AWS Infrastructure with Terraform and Ansible

This project sets up a complete AWS infrastructure using Terraform and configures the instances using Ansible. The infrastructure includes a VPC with public and private subnets, a NAT Gateway for internet access from private instances, and EC2 instances with proper security groups.

## Prerequisites

Before you begin, make sure you have the following installed on your local machine:

- **AWS CLI** - For authentication and access to AWS resources
- **Terraform** (version 1.0.0 or newer) - For infrastructure provisioning
- **Packer** (optional) - For creating custom AMIs
- **jq** - For JSON processing in the automation scripts
- **SSH Client** - For accessing the EC2 instances

## Setup Instructions

### 1. Configure AWS Credentials

### Prepare SSH Keys

make sure adding privatekey.pem under your folder

```bash
# Set correct permissions for your private key
chmod 600 private-key.pem

# Generate a public key from your private key
ssh-keygen -y -f /path/to/your/private-key.pem > publickey.pub
```

### Configure AWS Credentials

```bash
# Export your AWS credentials as environment variables
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_SESSION_TOKEN=your_session_token  # if using temporary credentials

# Export your public key for Packer to use
export SSH_PUBLIC_KEY=$(cat publickey.pub)
```

```

```

## Using the Automation Script

For a fully automated setup, use the provided automation script:

```bash
# Make the script executable
chmod +x scripts/aws-infrastructure-automation.sh

# Run the script (make sure your privatekey.pem is in the current directory)
./scripts/aws-infrastructure-automation.sh
```

The script will:

1. Check for prerequisites
2. Build custom AMIs with Packer (if configured)
3. Deploy the infrastructure with Terraform
4. Set up Ansible on the controller
5. Run the Ansible playbook

## Infrastructure Architecture

- **VPC**: A dedicated Virtual Private Cloud with CIDR range 10.0.0.0/16
- **Subnets**:
  - 3 Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
  - 3 Private Subnets (10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24)
- **NAT Gateway**: Allows private instances to access the internet
- **Internet Gateway**: Provides public instances with internet access
- **EC2 Instances**:
  - 1 Public instance serving as Ansible controller
  - 3 Ubuntu instances in private subnets
  - 3 Amazon Linux instances in private subnets

## Security

- Private instances are not directly accessible from the internet
- Only the Ansible controller has a public IP and is accessible via SSH
- Security groups restrict traffic to necessary ports only
- All communication between the controller and private instances uses the private key

## Cleanup

To avoid incurring charges, remove all resources when done:

```bash
terraform destroy
```

## Troubleshooting

### Issue: Private instances can't access the internet

- Verify the NAT Gateway is created and associated with the private route table
- Check that private subnets have `map_public_ip_on_launch = false`
- Ensure the private route table has a route for 0.0.0.0/0 pointing to the NAT Gateway

### Issue: Ansible playbook fails with connection errors

- Verify SSH key permissions (should be 600)
- Check security groups to ensure the controller can reach private instances on port 22
- Verify the inventory file has the correct private IPs

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS NAT Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
