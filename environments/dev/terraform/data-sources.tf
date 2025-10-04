# Data sources for direct variable usage
# This file provides local values for Terraform variables

# Local values for configuration
locals {
  # Cluster Configuration
  cluster_name = var.cluster_name
  proxmox_node = var.proxmox_node
  storage_pool = var.storage_pool
  
  # Network configuration
  talos_network_cidr = var.talos_network_cidr
  talos_network_gateway = var.talos_network_gateway
  management_network_cidr = var.management_network_cidr
  management_gateway = var.management_gateway
  
  # Proxmox configuration
  proxmox_api_url = var.proxmox_api_url
  proxmox_storage_pool = var.storage_pool
  
  # Kubernetes configuration
  k8s_version = var.k8s_version
  k8s_cni = var.k8s_cni
  k8s_pod_cidr = var.k8s_pod_cidr
  k8s_service_cidr = var.k8s_service_cidr
}

# Output configuration
output "parsed_configuration" {
  description = "Parsed configuration from variables"
  value = {
    proxmox = {
      node = local.proxmox_node
      api_url = local.proxmox_api_url
      storage_pool = local.proxmox_storage_pool
    }
    network = {
      talos_cidr = local.talos_network_cidr
      talos_gateway = local.talos_network_gateway
      management_cidr = local.management_network_cidr
      management_gateway = local.management_gateway
    }
    kubernetes = {
      version = local.k8s_version
      cni = local.k8s_cni
      pod_cidr = local.k8s_pod_cidr
      service_cidr = local.k8s_service_cidr
    }
    cluster = {
      name = local.cluster_name
      control_plane_count = var.control_plane_count
      worker_count = var.worker_count
    }
  }
}
