# Data sources for direct variable usage from Ansible
# This file provides dynamic input from Ansible inventory and group_vars

# External data source to get Ansible variables
data "external" "ansible_vars" {
  program = ["python3", "../../../shared/scripts/get-ansible-vars.py"]
  query = {
    environment = "dev"
    host        = "pve02"
  }
}

# Local values computed from Ansible variables
locals {
  # Core cluster configuration from Ansible
  cluster_name = data.external.ansible_vars.result.cluster_name
  talos_version = data.external.ansible_vars.result.talos_version
  
  # Node configuration
  control_plane_count = tonumber(data.external.ansible_vars.result.control_plane_count)
  worker_count = tonumber(data.external.ansible_vars.result.worker_count)
  
  # Control plane configuration
  control_plane_vm_ids = jsondecode(data.external.ansible_vars.result.control_plane_vm_ids)
  control_plane_ips = jsondecode(data.external.ansible_vars.result.control_plane_ips)
  control_plane_cores = tonumber(data.external.ansible_vars.result.control_plane_cores)
  control_plane_memory = tonumber(data.external.ansible_vars.result.control_plane_memory)
  control_plane_disk_size = data.external.ansible_vars.result.control_plane_disk_size
  
  # Worker configuration
  worker_vm_ids = jsondecode(data.external.ansible_vars.result.worker_vm_ids)
  worker_ips = jsondecode(data.external.ansible_vars.result.worker_ips)
  worker_cores = tonumber(data.external.ansible_vars.result.worker_cores)
  worker_memory = tonumber(data.external.ansible_vars.result.worker_memory)
  worker_disk_size = data.external.ansible_vars.result.worker_disk_size
  
  # Network configuration
  bridge_name = data.external.ansible_vars.result.bridge_name
  talos_network_cidr = data.external.ansible_vars.result.talos_network_cidr
  talos_network_gateway = data.external.ansible_vars.result.talos_network_gateway
  management_network_cidr = data.external.ansible_vars.result.management_network_cidr
  management_gateway = data.external.ansible_vars.result.management_gateway
  
  # NAT Gateway configuration
  enable_nat_gateway = data.external.ansible_vars.result.enable_nat_gateway == "true"
  nat_gateway_vm_id = tonumber(data.external.ansible_vars.result.nat_gateway_vm_id)
  nat_gateway_management_ip = data.external.ansible_vars.result.nat_gateway_management_ip
  nat_gateway_cluster_ip = data.external.ansible_vars.result.nat_gateway_cluster_ip
  openwrt_version = data.external.ansible_vars.result.openwrt_version
  
  # Security configuration
  enable_firewall = data.external.ansible_vars.result.enable_firewall == "true"
  ssh_public_keys = jsondecode(data.external.ansible_vars.result.ssh_public_keys)
  
  # Proxmox configuration
  proxmox_node = data.external.ansible_vars.result.proxmox_node
  storage_pool = data.external.ansible_vars.result.storage_pool
}
