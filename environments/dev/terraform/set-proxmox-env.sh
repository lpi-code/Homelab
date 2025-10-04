#!/bin/bash
# Script to set Proxmox environment variables for bpg/proxmox provider
# This script reads values from terraform.tfvars or uses defaults

# Source terraform.tfvars if it exists
if [ -f "terraform.tfvars" ]; then
    echo "Loading variables from terraform.tfvars..."
    # Extract values from terraform.tfvars (simple parsing)
    PROXMOX_HOST=$(grep 'proxmox_host' terraform.tfvars | cut -d'"' -f2)
    PROXMOX_USER=$(grep 'proxmox_user' terraform.tfvars | cut -d'"' -f2)
    PROXMOX_PASSWORD=$(grep 'proxmox_password' terraform.tfvars | cut -d'"' -f2)
    PROXMOX_TLS_INSECURE=$(grep 'proxmox_tls_insecure' terraform.tfvars | awk '{print $3}')
    
    # Construct API URL from host
    PROXMOX_API_URL="https://${PROXMOX_HOST}:8006/"
else
    echo "terraform.tfvars not found, using default values..."
    # Default values from variables.tf
    PROXMOX_API_URL="https://192.168.0.149:8006/"
    PROXMOX_USER="root@pam"
    PROXMOX_PASSWORD="changeme"
    PROXMOX_TLS_INSECURE="true"
fi

# Set environment variables for bpg/proxmox provider
export PROXMOX_VE_ENDPOINT="$PROXMOX_API_URL"
export PROXMOX_VE_USERNAME="$PROXMOX_USER"
export PROXMOX_VE_PASSWORD="$PROXMOX_PASSWORD"
export PROXMOX_VE_INSECURE="$PROXMOX_TLS_INSECURE"

echo "Proxmox environment variables set:"
echo "PROXMOX_VE_ENDPOINT=$PROXMOX_VE_ENDPOINT"
echo "PROXMOX_VE_USERNAME=$PROXMOX_VE_USERNAME"
echo "PROXMOX_VE_PASSWORD=$PROXMOX_VE_PASSWORD"
echo "PROXMOX_VE_INSECURE=$PROXMOX_VE_INSECURE"
echo ""
echo "You can now run terraform commands:"
echo "  terraform init -upgrade"
echo "  terraform plan"
echo "  terraform apply"
