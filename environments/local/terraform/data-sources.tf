# Data sources for local environment
# All environment-specific values come from Ansible inventory via get-ansible-vars.py.
# The external data source returns every value as a string; we decode types here.

data "external" "ansible_vars" {
  program = ["python3", "../../../shared/scripts/get-ansible-vars.py"]

  query = {
    environment = "local"
    host        = "pve02"
  }
}

locals {
  a = data.external.ansible_vars.result

  # Proxmox connection
  proxmox_user     = local.a.proxmox_user
  proxmox_password = local.a.proxmox_password
  proxmox_node     = local.a.proxmox_node

  # Cluster identity
  cluster_name  = local.a.cluster_name
  talos_version = local.a.talos_version
  storage_pool  = local.a.talos_storage_pool

  # Storage
  iso_pool            = local.a.proxmox_default_iso_pool
  talos_image_file_id = local.a.talos_image_file_id

  # Control plane
  control_plane_count        = tonumber(local.a.control_plane_count)
  control_plane_ips          = jsondecode(local.a.control_plane_ips)
  control_plane_vm_ids       = jsondecode(local.a.control_plane_vm_ids)
  control_plane_cores        = tonumber(local.a.control_plane_cores)
  control_plane_memory       = tonumber(local.a.control_plane_memory)
  control_plane_disk_size    = local.a.control_plane_disk_size
  control_plane_tunnel_ports = jsondecode(local.a.control_plane_tunnel_ports)

  # Workers
  worker_count        = tonumber(local.a.worker_count)
  worker_ips          = jsondecode(local.a.worker_ips)
  worker_vm_ids       = jsondecode(local.a.worker_vm_ids)
  worker_cores        = tonumber(local.a.worker_cores)
  worker_memory       = tonumber(local.a.worker_memory)
  worker_disk_size    = local.a.worker_disk_size
  worker_tunnel_ports = jsondecode(local.a.worker_tunnel_ports)

  # Network
  bridge_name             = local.a.bridge_name
  talos_network_cidr      = local.a.talos_network_cidr
  talos_network_gateway   = local.a.talos_network_gateway
  management_network_cidr = local.a.management_network_cidr
  management_gateway      = local.a.management_gateway

  # Firewall
  enable_firewall = tobool(local.a.enable_firewall)
}
