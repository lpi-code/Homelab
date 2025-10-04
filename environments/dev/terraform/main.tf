# Development Environment - Main Terraform Configuration
# This file defines the main infrastructure resources for the dev environment

# Use local backend for development
terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }
}

# Create Talos cluster using shared module
# All configuration comes from Ansible data sources - no environment overrides needed
module "talos_cluster" {
  source = "../../../shared/terraform/modules/talos-cluster"

  # Pass all variables from Ansible data source locals
  cluster_name                    = local.cluster_name
  proxmox_node                   = local.proxmox_node
  storage_pool                   = local.storage_pool
  talos_version                  = local.talos_version
  control_plane_count            = local.control_plane_count
  worker_count                   = local.worker_count
  control_plane_ips              = local.control_plane_ips
  control_plane_vm_ids           = local.control_plane_vm_ids
  control_plane_cores            = local.control_plane_cores
  control_plane_memory           = local.control_plane_memory
  control_plane_disk_size        = local.control_plane_disk_size
  worker_ips                     = local.worker_ips
  worker_vm_ids                  = local.worker_vm_ids
  worker_cores                   = local.worker_cores
  worker_memory                  = local.worker_memory
  worker_disk_size               = local.worker_disk_size
  bridge_name                    = local.bridge_name
  talos_network_cidr             = local.talos_network_cidr
  talos_network_gateway          = local.talos_network_gateway
  management_network_cidr        = local.management_network_cidr
  management_gateway             = local.management_gateway
  enable_nat_gateway             = local.enable_nat_gateway
  nat_gateway_vm_id              = local.nat_gateway_vm_id
  nat_gateway_management_ip      = local.nat_gateway_management_ip
  nat_gateway_cluster_ip         = local.nat_gateway_cluster_ip
  nat_gateway_password           = local.nat_gateway_password
  openwrt_version               = local.openwrt_version
  iso_pool                      = local.iso_pool
  enable_firewall               = local.enable_firewall
  ssh_public_keys                = local.ssh_public_keys
  openwrt_template_file_id       = local.openwrt_template_file_id
  talos_image_file_id            = local.talos_image_file_id
  control_plane_tunnel_ports     = local.control_plane_tunnel_ports
  worker_tunnel_ports           = local.worker_tunnel_ports
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
    nat_gateway = local.enable_nat_gateway ? {
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
    hostname = local.cluster_name
    environment = local.environment
    success = module.talos_cluster.bootstrap_complete
    cluster_ready = module.talos_cluster.cluster_ready
    total_nodes = local.control_plane_count + local.worker_count + (local.enable_nat_gateway ? 1 : 0)
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