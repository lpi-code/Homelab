# Development Environment - Main Terraform Configuration
# This file defines the main infrastructure resources for the dev environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0"
    }
  }
  
  # Use local backend for development
  backend "local" {
    path = "./terraform.tfstate"
  }
}

# Configure Proxmox provider
provider "proxmox" {
  pm_api_url      = local.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
  pm_timeout      = 600
}

# Proxmox VM resource using Ansible data
resource "proxmox_vm_qemu" "target_vm" {
  count = var.create_vm ? 1 : 0
  
  name        = var.target_host
  target_node = local.proxmox_node
  vmid        = local.vm_id
  
  # VM Configuration from Ansible
  memory = local.vm_memory
  cores  = local.vm_cores
  sockets = 1
  
  # Network configuration
  network {
    model  = "virtio"
    bridge = local.vm_network
  }
  
  # Disk configuration
  disk {
    type    = "scsi"
    storage = local.proxmox_storage_pool
    size    = local.vm_disk_size
    format  = "qcow2"
  }
  
  # Template configuration
  clone = local.vm_template
  
  # VM tags from Ansible
  tags = join(";", local.vm_tags)
  
  # Cloud-init configuration
  ciuser     = var.cloud_init_user
  cipassword = var.cloud_init_password
  sshkeys    = var.ssh_public_key
  
  # Network configuration for cloud-init
  ipconfig0 = "ip=${local.ansible_host_data.ansible_host}/24,gw=${local.network_gateway}"
  nameserver = join(" ", local.dns_servers)
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

# Output VM information
output "vm_info" {
  description = "Information about the created VM"
  value = var.create_vm ? {
    name = proxmox_vm_qemu.target_vm[0].name
    vmid = proxmox_vm_qemu.target_vm[0].vmid
    ip_address = proxmox_vm_qemu.target_vm[0].default_ipv4_address
    status = proxmox_vm_qemu.target_vm[0].status
  } : null
}

# Output Ansible integration status
output "ansible_integration_status" {
  description = "Status of Ansible integration"
  value = {
    success = data.external.ansible_host.result.success
    hostname = var.target_host
    environment = var.environment
    error = data.external.ansible_host.result.error
  }
}