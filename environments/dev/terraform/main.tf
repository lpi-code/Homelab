# Development Environment - Main Terraform Configuration
# This file defines the main infrastructure resources for the dev environment

# Use local backend for development
terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
}

# Create Talos cluster using shared module
module "talos_cluster" {
  source = "../../../shared/terraform/modules/talos-cluster"

  # Basic configuration
  cluster_name = var.cluster_name
  proxmox_node = var.proxmox_node
  storage_pool = var.storage_pool

  # Talos configuration
  talos_version = var.talos_version

  # Node configuration  
  control_plane_count = var.control_plane_count
  worker_count = var.worker_count

  # Control plane configuration
  control_plane_ips = var.control_plane_ips
  control_plane_vm_ids = var.control_plane_vm_ids
  control_plane_cores = var.control_plane_cores
  control_plane_memory = var.control_plane_memory
  control_plane_disk_size = var.control_plane_disk_size

  # Worker configuration
  worker_ips = var.worker_ips
  worker_vm_ids = var.worker_vm_ids
  worker_cores = var.worker_cores
  worker_memory = var.worker_memory
  worker_disk_size = var.worker_disk_size

  # Network configuration
  bridge_name = var.bridge_name
  talos_network_cidr = var.talos_network_cidr
  talos_network_gateway = var.talos_network_gateway
  management_network_cidr = var.management_network_cidr
  management_gateway = var.management_gateway

  # NAT Gateway configuration
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_vm_id = var.nat_gateway_vm_id
  nat_gateway_management_ip = var.nat_gateway_management_ip
  nat_gateway_cluster_ip = var.nat_gateway_cluster_ip
  nat_gateway_password = var.nat_gateway_password
  openwrt_version = var.openwrt_version
  iso_pool = var.iso_pool

  # Firewall configuration
  enable_firewall = var.enable_firewall

  # SSH keys for access
  ssh_public_keys = var.ssh_public_keys

  # OpenWrt configuration
  openwrt_template_file_id = var.openwrt_template_file_id
  talos_image_file_id = var.talos_image_file_id

  # Tunnel configuration
  control_plane_tunnel_ports = var.control_plane_tunnel_ports
  worker_tunnel_ports = var.worker_tunnel_ports
}

# Output cluster information
output "cluster_info" {
  description = "Information about the created Talos cluster"
  value = {
    cluster_name = module.talos_cluster.cluster_name
    cluster_endpoint = module.talos_cluster.cluster_endpoint
    control_plane_nodes = {
      for i, name in module.talos_cluster.control_plane_names : name => {
        vmid = module.talos_cluster.control_plane_vm_ids[i]
        ip   = module.talos_cluster.control_plane_ips[i]
        name = name
      }
    }
    worker_nodes = {
      for i, name in module.talos_cluster.worker_names : name => {
        vmid = module.talos_cluster.worker_vm_ids[i]
        ip   = module.talos_cluster.worker_ips[i]
        name = name
      }
    }
    nat_gateway = var.enable_nat_gateway ? {
      vmid = module.talos_cluster.nat_gateway_vm_id
      management_ip = module.talos_cluster.nat_gateway_management_ip
      cluster_ip = module.talos_cluster.nat_gateway_cluster_ip
    } : null
    network_info = {
      bridge_name = module.talos_cluster.bridge_name
      bridge_ip = module.talos_cluster.bridge_ipv4_address
      talos_network_cidr = module.talos_cluster.talos_network_cidr
      talos_network_gateway = module.talos_cluster.talos_network_gateway
    }
    tunnel_info = {
      control_plane_tunnels = module.talos_cluster.control_plane_tunnel_info
      worker_tunnels = module.talos_cluster.worker_tunnel_info
      all_tunnels = module.talos_cluster.all_tunnel_info
    }
  }
}

# Output deployment status
output "deployment_status" {
  description = "Status of deployment"
  value = {
    hostname = var.cluster_name
    environment = var.environment
    success = module.talos_cluster.bootstrap_complete
    cluster_ready = module.talos_cluster.cluster_ready
    total_nodes = var.control_plane_count + var.worker_count + (var.enable_nat_gateway ? 1 : 0)
  }
}

# Output Talos configuration (sensitive)
output "talos_client_configuration" {
  description = "Talos client configuration"
  value = module.talos_cluster.client_configuration
  sensitive = true
}

output "talos_machine_secrets" {
  description = "Talos machine secrets"
  value = module.talos_cluster.machine_secrets
  sensitive = true
}

resource "local_file" "talos_client_configuration" {
  content = jsonencode(module.talos_cluster.client_configuration)
  filename = "talos_client_configuration.yaml"
}

resource "local_file" "kubeconfig" {
  content = module.talos_cluster.kubeconfig
  filename = "kubeconfig.yaml"
  file_permission = "0600"
}