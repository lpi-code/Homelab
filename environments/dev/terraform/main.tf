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
  pm_api_url      = "https://${var.proxmox_host}:8006/"
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
  pm_timeout      = 600
}

# Data source to check existing VMs
data "proxmox_virtual_environment_vms" "existing_vms" {
  node_name = var.proxmox_node
}

# Local values for VM ID management
locals {
  # Get list of existing VM IDs
  existing_vm_ids = [for vm in data.proxmox_virtual_environment_vms.existing_vms.vms : vm.vm_id]
  
  # Find next available VM IDs
  control_plane_vm_ids = [
    for i in range(var.control_plane_count) : 
    var.control_plane_vm_ids[i] if var.control_plane_vm_ids[i] != null && !contains(local.existing_vm_ids, var.control_plane_vm_ids[i])
  ]
  
  worker_vm_ids = [
    for i in range(var.worker_count) : 
    var.worker_vm_ids[i] if var.worker_vm_ids[i] != null && !contains(local.existing_vm_ids, var.worker_vm_ids[i])
  ]
  
  nat_gateway_vm_id = var.nat_gateway_vm_id != null && !contains(local.existing_vm_ids, var.nat_gateway_vm_id) ? var.nat_gateway_vm_id : null
}

# NAT Gateway VM (if enabled)
resource "proxmox_virtual_environment_vm" "nat_gateway" {
  count = var.nat_gateway_enabled && local.nat_gateway_vm_id != null ? 1 : 0
  
  name        = "${var.cluster_name}-nat-gateway"
  node_name   = var.proxmox_node
  vm_id       = local.nat_gateway_vm_id
  
  # VM Configuration
  memory = var.nat_gateway_memory
  cores  = var.nat_gateway_cores
  sockets = 1
  
  # Network configuration
  network_device {
    bridge = "vmbr0"
  }
  
  # Disk configuration
  disk {
    datastore_id = var.storage_pool
    file_id      = "local:iso/${var.openwrt_filename}"
    interface    = "virtio0"
  }
  
  # Cloud-init configuration
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_nat_gateway.id
  }
  
  # Tags
  tags = ["talos", "nat-gateway", var.environment]
  
  lifecycle {
    ignore_changes = [
      network_device,
      disk,
    ]
  }
}

# Control Plane VMs
resource "proxmox_virtual_environment_vm" "control_plane" {
  count = var.control_plane_count
  
  name        = "${var.cluster_name}-control-plane-${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = local.control_plane_vm_ids[count.index]
  
  # VM Configuration
  memory = var.control_plane_memory
  cores  = var.control_plane_cores
  sockets = 1
  
  # Network configuration
  network_device {
    bridge = "vmbr0"
  }
  
  # Disk configuration
  disk {
    datastore_id = var.storage_pool
    file_id      = "local:iso/talos-${var.talos_version}-amd64.iso"
    interface    = "virtio0"
  }
  
  # Cloud-init configuration
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_control_plane[count.index].id
  }
  
  # Tags
  tags = ["talos", "control-plane", var.environment]
  
  lifecycle {
    ignore_changes = [
      network_device,
      disk,
    ]
  }
}

# Worker VMs
resource "proxmox_virtual_environment_vm" "worker" {
  count = var.worker_count
  
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = local.worker_vm_ids[count.index]
  
  # VM Configuration
  memory = var.worker_memory
  cores  = var.worker_cores
  sockets = 1
  
  # Network configuration
  network_device {
    bridge = "vmbr0"
  }
  
  # Disk configuration
  disk {
    datastore_id = var.storage_pool
    file_id      = "local:iso/talos-${var.talos_version}-amd64.iso"
    interface    = "virtio0"
  }
  
  # Cloud-init configuration
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_worker[count.index].id
  }
  
  # Tags
  tags = ["talos", "worker", var.environment]
  
  lifecycle {
    ignore_changes = [
      network_device,
      disk,
    ]
  }
}

# Cloud-init files for NAT Gateway
resource "proxmox_virtual_environment_file" "cloud_init_nat_gateway" {
  count = var.nat_gateway_enabled && local.nat_gateway_vm_id != null ? 1 : 0
  
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node
  
  source_raw {
    data = templatefile("${path.module}/templates/nat-gateway-cloud-init.yaml", {
      ssh_public_key = var.ssh_public_key
      cluster_name   = var.cluster_name
    })
    file_name = "nat-gateway-cloud-init.yaml"
  }
}

# Cloud-init files for Control Plane
resource "proxmox_virtual_environment_file" "cloud_init_control_plane" {
  count = var.control_plane_count
  
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node
  
  source_raw {
    data = templatefile("${path.module}/templates/control-plane-cloud-init.yaml", {
      ssh_public_key = var.ssh_public_key
      cluster_name   = var.cluster_name
      node_index     = count.index
      talos_version  = var.talos_version
      kubernetes_version = var.kubernetes_version
    })
    file_name = "control-plane-${count.index}-cloud-init.yaml"
  }
}

# Cloud-init files for Workers
resource "proxmox_virtual_environment_file" "cloud_init_worker" {
  count = var.worker_count
  
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node
  
  source_raw {
    data = templatefile("${path.module}/templates/worker-cloud-init.yaml", {
      ssh_public_key = var.ssh_public_key
      cluster_name   = var.cluster_name
      node_index     = count.index
      talos_version  = var.talos_version
      kubernetes_version = var.kubernetes_version
    })
    file_name = "worker-${count.index}-cloud-init.yaml"
  }
}

# Outputs
output "cluster_info" {
  description = "Information about the created Talos cluster"
  value = {
    cluster_name = var.cluster_name
    environment = var.environment
    control_plane_vms = {
      for i, vm in proxmox_virtual_environment_vm.control_plane : vm.name => {
        vm_id = vm.vm_id
        ip_address = vm.ipv4_addresses[0] if length(vm.ipv4_addresses) > 0 else null
      }
    }
    worker_vms = {
      for i, vm in proxmox_virtual_environment_vm.worker : vm.name => {
        vm_id = vm.vm_id
        ip_address = vm.ipv4_addresses[0] if length(vm.ipv4_addresses) > 0 else null
      }
    }
    nat_gateway = var.nat_gateway_enabled && local.nat_gateway_vm_id != null ? {
      vm_id = proxmox_virtual_environment_vm.nat_gateway[0].vm_id
      ip_address = proxmox_virtual_environment_vm.nat_gateway[0].ipv4_addresses[0] if length(proxmox_virtual_environment_vm.nat_gateway[0].ipv4_addresses) > 0 else null
    } : null
  }
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value = var.control_plane_count > 0 ? proxmox_virtual_environment_vm.control_plane[0].ipv4_addresses[0] : null
}

output "cluster_ready" {
  description = "Whether the cluster is ready"
  value = var.control_plane_count > 0 && var.worker_count > 0
}

output "talos_network_cidr" {
  description = "Talos network CIDR"
  value = var.talos_network_cidr
}

output "nat_gateway_management_ip" {
  description = "NAT Gateway management IP"
  value = var.nat_gateway_enabled && local.nat_gateway_vm_id != null ? proxmox_virtual_environment_vm.nat_gateway[0].ipv4_addresses[0] : null
}
