#!/bin/bash
# AWS Infrastructure Automation Script
# This script automates the entire process from creating AMIs with Packer
# to deploying infrastructure with Terraform and setting up Ansible

set -e # Exit on error

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Log function
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
  exit 1
}

warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
  log "Checking prerequisites..."
  
  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install it first."
  fi
  
  # Check Terraform
  if ! command -v terraform &> /dev/null; then
    error "Terraform is not installed. Please install it first."
  fi
  
  # Check Packer
  if ! command -v packer &> /dev/null; then
    error "Packer is not installed. Please install it first."
  fi

  # Check jq (JSON processor)
  if ! command -v jq &> /dev/null; then
    warning "jq is not installed. This tool is required to process JSON outputs from Terraform."
    warning "Installation instructions:"
    warning "  - Ubuntu/Debian: sudo apt install -y jq"
    warning "  - Amazon Linux/RHEL/CentOS: sudo yum install -y jq"
    warning "  - macOS: brew install jq"
    
    read -p "Would you like to try to install jq now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y jq
      elif command -v yum &> /dev/null; then
        sudo yum install -y jq
      elif command -v brew &> /dev/null; then
        brew install jq
      else
        error "Automatic installation not supported for your OS. Please install jq manually and run the script again."
      fi
      
      # Verify installation
      if ! command -v jq &> /dev/null; then
        error "Failed to install jq. Please install it manually and run the script again."
      else
        log "jq installed successfully."
      fi
    else
      error "jq is required. Please install it manually and run the script again."
    fi
  fi
  
  # Check private key file
  if [ ! -f "privatekey.pem" ]; then
    error "privatekey.pem file not found in the current directory."
  fi
  
  # Check AWS credentials
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    warning "AWS credentials not found in environment variables."
    warning "You will need to configure AWS credentials."
    
    # Ask user if they want to configure AWS credentials now
    read -p "Do you want to configure AWS credentials now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      aws configure
    else
      warning "Continuing without configuring AWS credentials."
      warning "This script may fail if your credentials are not configured properly."
    fi
  else
    log "AWS credentials found in environment variables."
  fi
  
  # Set correct permissions for private key
  chmod 600 privatekey.pem
  
  # Generate public key from private key
  if [ ! -f "publickey.pub" ]; then
    log "Generating public key from private key..."
    ssh-keygen -y -f privatekey.pem > publickey.pub
    if [ $? -ne 0 ]; then
      error "Failed to generate public key from private key."
    fi
  fi
  
  log "All prerequisites checked."
}

# Build AMIs with Packer
build_amis() {
  log "Building custom AMIs with Packer..."
  
  # Export SSH public key for Packer
  export SSH_PUBLIC_KEY=$(cat publickey.pub)
  
  # Initialize Packer plugins
  log "Initializing Packer plugins..."
  packer init .
  
  # Build AMIs
  log "Building AMIs (this may take some time)..."
  packer build .
  
  # Get AMI IDs
  UBUNTU_AMI=$(aws ec2 describe-images --owners self --filters "Name=name,Values=custom-ubuntu-*" --query 'Images[0].ImageId' --output text)
  AMAZON_AMI=$(aws ec2 describe-images --owners self --filters "Name=name,Values=custom-amazon-*" --query 'Images[0].ImageId' --output text)
  
  log "Ubuntu AMI created: $UBUNTU_AMI"
  log "Amazon Linux AMI created: $AMAZON_AMI"
  
  # Update vars.tf with AMI IDs
  if [ -n "$UBUNTU_AMI" ] && [ -n "$AMAZON_AMI" ]; then
    log "Updating AMIS and MYIP in vars.tf..."
    
    # Check if vars.tf exists
    if [ ! -f "vars.tf" ]; then
      error "vars.tf file not found. Please make sure it exists in the current directory."
    fi
    
    # Get current public IP
    CURRENT_IP="$(curl -s -4 icanhazip.com)"
    
    # Create a backup first
    cp vars.tf vars.tf.bak
    
    # Detect OS type for sed command compatibility (macOS vs Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS version
      # Create new file with updated AMIS and MYIP variables
      awk 'BEGIN{p=1} 
           /variable "AMIS" {/{
             print "variable \"AMIS\" {";
             print "  default = {";
             print "    us-east-1 = {";
             print "      \"amazon\" = \"'"$AMAZON_AMI"'\"";
             print "      \"ubuntu\" = \"'"$UBUNTU_AMI"'\"";
             print "    }";
             print "  }";
             print "}";
             p=0;
           }
           /^}$/ && p==0 {p=1; next}
           /variable "MYIP" {/{
             print "variable \"MYIP\" {";
             print "  default = \"'"$CURRENT_IP"'\"";
             print "}";
             p=0;
           }
           p==1 {print}' vars.tf.bak > vars.tf
    else
      # Linux version
      # Update AMIS variable
      sed -i '/variable "AMIS" {/,/}/c\
variable "AMIS" {\
  default = {\
    us-east-1 = {\
      "amazon" = "'"$AMAZON_AMI"'"\
      "ubuntu" = "'"$UBUNTU_AMI"'"\
    }\
  }\
}' vars.tf
      
      # Update MYIP variable
      sed -i '/variable "MYIP" {/,/}/c\
variable "MYIP" {\
  default = "'"$CURRENT_IP"'"\
}' vars.tf
    fi
    
    log "vars.tf updated successfully. Backup saved as vars.tf.bak."
  else
    error "Failed to get AMI IDs. Check Packer build logs."
  fi
  
  log "Custom AMIs built and vars.tf updated."
}

# Provision infrastructure with Terraform
provision_infrastructure() {
  log "Provisioning infrastructure with Terraform..."
  
  # Initialize Terraform
  log "Initializing Terraform..."
  terraform init
  
  # Validate configuration
  log "Validating Terraform configuration..."
  terraform validate
  
  # Format configuration files
  log "Formatting Terraform configuration files..."
  terraform fmt
  
  # Apply configuration
  log "Creating infrastructure (this may take some time)..."
  terraform apply -auto-approve
  
  # Extract outputs
  log "Extracting Terraform outputs..."
  ANSIBLE_CONTROLLER_IP=$(terraform output -raw AnsibleControllerPublicIP)
  PRIVATE_IPS=$(terraform output -json PrivateIPs | jq -r '.[]')
  INSTANCE_OS=$(terraform output -json InstanceOS | jq -r '.[]')
  
  # Save outputs to file for later use
  log "Saving outputs to terraform_outputs.json..."
  terraform output -json > terraform_outputs.json
  
  log "Infrastructure provisioned successfully."
  log "Ansible Controller Public IP: $ANSIBLE_CONTROLLER_IP"
}

# Set up Ansible on the controller
setup_ansible() {
  log "Setting up Ansible on the controller..."
  
  # Get the controller's public IP
  ANSIBLE_CONTROLLER_IP=$(jq -r '.AnsibleControllerPublicIP.value' terraform_outputs.json)
  PRIVATE_IPS=$(jq -r '.PrivateIPs.value[]' terraform_outputs.json)
  INSTANCE_OS=$(jq -r '.InstanceOS.value[]' terraform_outputs.json)
  
  # Create inventory.ini file
  log "Creating inventory.ini file..."
  
  cat > inventory.ini << EOF
[ubuntu]
EOF

  cat > inventory_temp.ini << EOF
[amazon]
EOF

  # Add hosts to inventory file
  UBUNTU_COUNT=1
  AMAZON_COUNT=1
  
  for i in $(seq 0 $(($(echo "$PRIVATE_IPS" | wc -l) - 1))); do
    OS=$(echo "$INSTANCE_OS" | sed -n "$((i+1))p")
    IP=$(echo "$PRIVATE_IPS" | sed -n "$((i+1))p")
    
    if [ "$OS" == "ubuntu" ]; then
      echo "ubuntu-$UBUNTU_COUNT ansible_host=$IP" >> inventory.ini
      UBUNTU_COUNT=$((UBUNTU_COUNT+1))
    elif [ "$OS" == "amazon" ]; then
      echo "amazon-$AMAZON_COUNT ansible_host=$IP" >> inventory_temp.ini
      AMAZON_COUNT=$((AMAZON_COUNT+1))
    fi
  done
  
  # Combine inventory files
  cat inventory_temp.ini >> inventory.ini
  rm inventory_temp.ini
  
  # Add variables to inventory file
  cat >> inventory.ini << EOF

[ubuntu:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/privatekey.pem

[amazon:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/.ssh/privatekey.pem

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
  
  # Create EC2 management playbook
  log "Creating EC2 management playbook..."
  cat > ec2-management.yml << EOF
---
- name: EC2 Instance Management
  hosts: all
  become: yes
  gather_facts: yes
  
  tasks:
    - name: Create output directory for reports
      file:
        path: "{{ playbook_dir }}/reports"
        state: directory
      delegate_to: localhost
      run_once: true
      become: no
      
    # Update and upgrade packages based on OS type
    - name: Update and upgrade apt packages
      ansible.builtin.apt:
        update_cache: yes
        upgrade: dist
      when: ansible_os_family == "Debian"

    - name: Update and upgrade yum packages
      ansible.builtin.yum:
        name: "*"
        state: latest
        update_cache: yes
      when: ansible_os_family == "RedHat"
      
    # Verify Docker version
    - name: Check Docker version
      ansible.builtin.command: docker --version
      register: docker_version
      changed_when: false
      ignore_errors: true

    - name: Display Docker version
      ansible.builtin.debug:
        msg: "Docker version: {{ docker_version.stdout | default('Docker not installed') }}"

    # Report disk usage
    - name: Get disk usage
      ansible.builtin.shell: df -h
      register: disk_usage
      changed_when: false
      
    # Display report summary
    - name: Display disk usage report
      debug:
        msg: 
          - "Host: {{ inventory_hostname }}"
          - "Docker version: {{ docker_version.stdout | default('Docker not installed') }}"
          - "Disk usage summary:"
          - "{{ disk_usage.stdout_lines | join('\n  ') }}"
EOF
  
  # Create setup script for the controller
  log "Creating setup script for the controller..."
  cat > setup-ansible-controller.sh << EOF
#!/bin/bash
# Ansible Controller Setup Script

# Update system
sudo apt update -y
sudo apt upgrade -y

# Install Ansible
sudo apt install -y ansible

# Create project directory
mkdir -p ~/ansible-ec2-management
cd ~/ansible-ec2-management

# Create SSH directory and set permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Copy private key
cp /tmp/privatekey.pem ~/.ssh/
chmod 600 ~/.ssh/privatekey.pem

# Copy inventory and playbook files
cp /tmp/inventory.ini ~/ansible-ec2-management/
cp /tmp/ec2-management.yml ~/ansible-ec2-management/

# Create reports directory
mkdir -p ~/ansible-ec2-management/reports

# Test connectivity
echo "Testing connectivity to all hosts..."
ansible all -i inventory.ini -m ping

# Run playbook
echo "Running EC2 management playbook..."
ansible-playbook -i inventory.ini ec2-management.yml
EOF
  
  # Copy files to the controller
  log "Copying files to the Ansible controller..."
  
  # Wait for SSH to be available on the controller
  log "Waiting for SSH to be available on the controller..."
  while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i privatekey.pem ubuntu@$ANSIBLE_CONTROLLER_IP echo success 2>/dev/null
  do
    echo "Waiting for SSH to become available..."
    sleep 10
  done
  
  # Copy files
  scp -o StrictHostKeyChecking=no -i privatekey.pem privatekey.pem ubuntu@$ANSIBLE_CONTROLLER_IP:/tmp/
  scp -o StrictHostKeyChecking=no -i privatekey.pem inventory.ini ubuntu@$ANSIBLE_CONTROLLER_IP:/tmp/
  scp -o StrictHostKeyChecking=no -i privatekey.pem ec2-management.yml ubuntu@$ANSIBLE_CONTROLLER_IP:/tmp/
  scp -o StrictHostKeyChecking=no -i privatekey.pem setup-ansible-controller.sh ubuntu@$ANSIBLE_CONTROLLER_IP:/tmp/
  
  # Execute setup script on the controller
  log "Executing setup script on the controller..."
  ssh -o StrictHostKeyChecking=no -i privatekey.pem ubuntu@$ANSIBLE_CONTROLLER_IP "chmod +x /tmp/setup-ansible-controller.sh && /tmp/setup-ansible-controller.sh"
  
  log "Ansible setup completed on the controller."
}

# Main function
main() {
  log "Starting AWS Infrastructure Automation"
  
  # Check prerequisites
  check_prerequisites
  
  # Build AMIs with Packer
  build_amis
  
  # Provision infrastructure with Terraform
  provision_infrastructure
  
  # Setup Ansible
  setup_ansible
  
  log "AWS Infrastructure Automation completed successfully!"
  log "Ansible Controller Public IP: $(jq -r '.AnsibleControllerPublicIP.value' terraform_outputs.json)"
  log "You can SSH into the controller with: ssh -i privatekey.pem ubuntu@$(jq -r '.AnsibleControllerPublicIP.value' terraform_outputs.json)"
}

# Run main function
main