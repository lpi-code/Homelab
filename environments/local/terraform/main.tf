# Local Development Environment - Terraform Configuration
# Deploys a Talos Kubernetes cluster on the local Vagrant Proxmox VE.
# All environment-specific values come from Ansible inventory (host_vars/pve02/).

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  # bpg/proxmox expects the base URL without /api2/json
  endpoint = "https://${var.proxmox_host}:8006/"
  username = "${local.proxmox_user}@pve"
  password = local.proxmox_password
  insecure = true

  ssh {
    agent    = true
    username = "root"
  }
}

module "talos_cluster" {
  source = "../../../shared/terraform/modules/talos-cluster"

  # Cluster identity
  cluster_name  = local.cluster_name
  proxmox_node  = local.proxmox_node
  storage_pool  = local.storage_pool
  talos_version = local.talos_version
  iso_pool      = local.iso_pool
  talos_image_file_id = local.talos_image_file_id

  # Control plane
  control_plane_count        = local.control_plane_count
  control_plane_ips          = local.control_plane_ips
  control_plane_vm_ids       = local.control_plane_vm_ids
  control_plane_cores        = local.control_plane_cores
  control_plane_memory       = local.control_plane_memory
  control_plane_disk_size    = local.control_plane_disk_size
  control_plane_tunnel_ports = local.control_plane_tunnel_ports

  # Workers
  worker_count        = local.worker_count
  worker_ips          = local.worker_ips
  worker_vm_ids       = local.worker_vm_ids
  worker_cores        = local.worker_cores
  worker_memory       = local.worker_memory
  worker_disk_size    = local.worker_disk_size
  worker_tunnel_ports = local.worker_tunnel_ports

  # Network
  bridge_name             = local.bridge_name
  talos_network_cidr      = local.talos_network_cidr
  talos_network_gateway   = local.talos_network_gateway
  management_network_cidr = local.management_network_cidr
  management_gateway      = local.management_gateway

  # Firewall
  enable_firewall = local.enable_firewall
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.talos_cluster.cluster_endpoint
}

output "talosconfig" {
  description = "Talos configuration"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes configuration"
  value       = module.talos_cluster.kubeconfig
  sensitive   = true
}

resource "local_file" "kubeconfig" {
  content         = module.talos_cluster.kubeconfig
  filename        = "${path.module}/../kubeconfig"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = module.talos_cluster.talosconfig
  filename        = "${path.module}/../talosconfig"
  file_permission = "0600"
}
