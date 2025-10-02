#!/bin/bash
# VM Template Migration Script
# This script helps migrate from Terraform-based templates to Packer-based templates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "shared/packer" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "Starting VM template migration to Packer-based system..."

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Packer is installed
if ! command -v packer &> /dev/null; then
    print_error "Packer is not installed. Please install Packer first."
    print_status "Visit: https://www.packer.io/downloads"
    exit 1
fi

print_status "Packer is installed: $(packer version | head -n1)"

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed. Please install Ansible first."
    exit 1
fi

print_status "Ansible is installed: $(ansible --version | head -n1)"

# Check if Terraform/OpenTofu is installed
if command -v tofu &> /dev/null; then
    print_status "OpenTofu is installed: $(tofu version | head -n1)"
elif command -v terraform &> /dev/null; then
    print_status "Terraform is installed: $(terraform version | head -n1)"
else
    print_warning "Neither Terraform nor OpenTofu is installed. You may need one for VM deployment."
fi

# Check if required directories exist
print_status "Checking directory structure..."

required_dirs=(
    "shared/packer/talos"
    "shared/packer/openwrt"
    "shared/ansible/playbooks"
    "environments/dev/ansible"
    "environments/dev/terraform"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_status "✓ $dir exists"
    else
        print_error "✗ $dir does not exist"
        exit 1
    fi
done

# Check if required files exist
print_status "Checking required files..."

required_files=(
    "shared/packer/talos/talos-template.pkr.hcl"
    "shared/packer/openwrt/openwrt-template.pkr.hcl"
    "shared/ansible/playbooks/02-create-vm-template.yml"
    "shared/ansible/playbooks/03-deploy-terraform.yml"
    "shared/scripts/terraform/ansible_data_source.py"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "✓ $file exists"
    else
        print_error "✗ $file does not exist"
        exit 1
    fi
done

# Check if ansible_data_source.py is executable
if [ -x "shared/scripts/terraform/ansible_data_source.py" ]; then
    print_status "✓ ansible_data_source.py is executable"
else
    print_warning "Making ansible_data_source.py executable..."
    chmod +x shared/scripts/terraform/ansible_data_source.py
fi

# Validate Ansible inventory
print_status "Validating Ansible inventory..."

if [ -f "environments/dev/ansible/inventory/hosts.toml" ]; then
    print_status "✓ Ansible inventory exists"
    
    # Test inventory parsing
    if ansible-inventory -i environments/dev/ansible/inventory/hosts.toml --list > /dev/null 2>&1; then
        print_status "✓ Ansible inventory is valid"
    else
        print_error "✗ Ansible inventory is invalid"
        exit 1
    fi
else
    print_error "✗ Ansible inventory does not exist"
    exit 1
fi

# Test terraform data source script
print_status "Testing Terraform data source script..."

if python3 shared/scripts/terraform/ansible_data_source.py --hostname pve02 --environment dev > /dev/null 2>&1; then
    print_status "✓ Terraform data source script works"
else
    print_warning "Terraform data source script test failed (this may be expected if Proxmox is not accessible)"
fi

# Check Packer configurations
print_status "Validating Packer configurations..."

# Check Talos configuration
if packer validate shared/packer/talos/talos-template.pkr.hcl > /dev/null 2>&1; then
    print_status "✓ Talos Packer configuration is valid"
else
    print_error "✗ Talos Packer configuration is invalid"
    packer validate shared/packer/talos/talos-template.pkr.hcl
    exit 1
fi

# Check OpenWrt configuration
if packer validate shared/packer/openwrt/openwrt-template.pkr.hcl > /dev/null 2>&1; then
    print_status "✓ OpenWrt Packer configuration is valid"
else
    print_error "✗ OpenWrt Packer configuration is invalid"
    packer validate shared/packer/openwrt/openwrt-template.pkr.hcl
    exit 1
fi

# Check Ansible playbooks
print_status "Validating Ansible playbooks..."

if ansible-playbook --syntax-check shared/ansible/playbooks/02-create-vm-template.yml > /dev/null 2>&1; then
    print_status "✓ Template creation playbook syntax is valid"
else
    print_error "✗ Template creation playbook syntax is invalid"
    ansible-playbook --syntax-check shared/ansible/playbooks/02-create-vm-template.yml
    exit 1
fi

if ansible-playbook --syntax-check shared/ansible/playbooks/03-deploy-terraform.yml > /dev/null 2>&1; then
    print_status "✓ Terraform deployment playbook syntax is valid"
else
    print_error "✗ Terraform deployment playbook syntax is invalid"
    ansible-playbook --syntax-check shared/ansible/playbooks/03-deploy-terraform.yml
    exit 1
fi

# Summary
print_status "Migration validation completed successfully!"
print_status ""
print_status "Next steps:"
print_status "1. Ensure Proxmox is accessible and configured"
print_status "2. Run: ansible-playbook shared/ansible/playbooks/02-create-vm-template.yml"
print_status "3. Run: ansible-playbook shared/ansible/playbooks/03-deploy-terraform.yml"
print_status ""
print_status "For more information, see: shared/packer/README.md"