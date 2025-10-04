# Talos Cluster Module
# Creates a complete Talos Kubernetes cluster with control plane and worker nodes

locals {
  # Network configuration
  net_cidr_suffix = split("/", var.talos_network_cidr)[1]
  
  # Generate cluster endpoint (direct to first control plane)
  cluster_endpoint = "https://${var.control_plane_ips[0]}:6443"
}

# Create network infrastructure
module "network" {
  source = "../talos-network"

  # Basic configuration
  proxmox_node = var.proxmox_node
  cluster_name = var.cluster_name
  storage_pool = var.storage_pool

  # Bridge configuration
  bridge_name = var.bridge_name
  bridge_ipv4_address = "${var.talos_network_gateway}/${local.net_cidr_suffix}"

  # Network configuration
  talos_network_cidr = var.talos_network_cidr
  talos_network_gateway = var.talos_network_gateway
  management_network_cidr = var.management_network_cidr
  management_gateway = var.management_gateway

  # NAT gateway configuration
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_vm_id = var.nat_gateway_vm_id
  nat_gateway_management_ip = var.nat_gateway_management_ip
  nat_gateway_cluster_ip = var.nat_gateway_cluster_ip
  nat_gateway_password = var.nat_gateway_password
  openwrt_version = var.openwrt_version
  iso_pool = var.iso_pool

  # Firewall configuration
  enable_firewall = var.enable_firewall

  # OpenWrt configuration
  openwrt_template_file_id = var.openwrt_template_file_id
}

# Generate Talos machine secrets
resource "talos_machine_secrets" "cluster" {
}

# Create control plane nodes
module "control_plane" {
  source = "../talos-vm"
  count  = var.control_plane_count

  # VM Configuration
  vm_name        = "${var.cluster_name}-cp-${count.index + 1}"
  vm_id          = var.control_plane_vm_ids[count.index]

  # Disk Configuration - use specific disk for each control plane node
  disk_image_file_id = var.talos_image_file_id

  # Proxmox Configuration
  proxmox_node = var.proxmox_node
  storage_pool = var.storage_pool

  # Network Configuration
  network_bridge      = module.network.bridge_name
  use_static_ip       = true
  static_ip          = var.control_plane_ips[count.index]
  network_gateway    = var.talos_network_gateway
  network_cidr_suffix = tonumber(local.net_cidr_suffix)

  # Talos Configuration
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  node_type        = "controlplane"
  node_index       = count.index

  # Machine secrets and client configuration
  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  client_configuration = talos_machine_secrets.cluster.client_configuration

  # Configuration patches
  config_patches = [
    templatefile("${path.module}/templates/controlplane.yaml.tpl", {
      cluster_endpoint = local.cluster_endpoint
      gateway = var.talos_network_gateway
      talos_version = var.talos_version
      cluster_name = var.cluster_name
      use_static_ips = true
      node_ip = var.control_plane_ips[count.index]
      hostname = "${var.cluster_name}-cp-${count.index + 1}"
      temp_ip = var.nat_gateway_cluster_ip
    })
  ]

  # VM Resources
  vm_cores    = var.control_plane_cores
  vm_memory   = var.control_plane_memory
  vm_disk_size = var.control_plane_disk_size

  # Tags
  tags = ["talos", "controlplane", var.cluster_name]

  # Tunnel configuration
  tunnel_local_port = var.control_plane_tunnel_ports[count.index]
}

# Create worker nodes
module "workers" {
  source = "../talos-vm"
  count  = var.worker_count

  # VM Configuration
  vm_name        = "${var.cluster_name}-worker-${count.index + 1}"
  vm_id          = var.worker_vm_ids[count.index]

  # Disk Configuration - use specific disk for each worker node
  disk_image_file_id = var.talos_image_file_id


  # Proxmox Configuration
  proxmox_node = var.proxmox_node
  storage_pool = var.storage_pool

  # Network Configuration
  network_bridge      = module.network.bridge_name
  use_static_ip       = true
  static_ip          = var.worker_ips[count.index]
  network_gateway    = var.talos_network_gateway
  network_cidr_suffix = tonumber(local.net_cidr_suffix)

  # Talos Configuration
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  node_type        = "worker"
  node_index       = count.index

  # Machine secrets and client configuration
  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  client_configuration = talos_machine_secrets.cluster.client_configuration

  # Configuration patches
  config_patches = [
    templatefile("${path.module}/templates/worker.yaml.tpl", {
      gateway = var.talos_network_gateway
      talos_version = var.talos_version
      use_static_ips = true
      node_ip = var.worker_ips[count.index]
      hostname = "${var.cluster_name}-worker-${count.index + 1}"
    })
  ]

  # VM Resources
  vm_cores    = var.worker_cores
  vm_memory   = var.worker_memory
  vm_disk_size = var.worker_disk_size

  # Tags
  tags = ["talos", "worker", var.cluster_name]

  # Tunnel configuration
  tunnel_local_port = var.worker_tunnel_ports[count.index]
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoint                 = "dev-talos-cp-1:${var.control_plane_tunnel_ports[0]}"
  node = "10.10.0.10"
  depends_on = [
    module.control_plane,
    module.workers,
  ]
  timeouts = {
    create = "20s"
    delete = "1m"
    update = "1m"
  }
}

# Generate kubeconfig
data "talos_client_configuration" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  cluster_name         = var.cluster_name

  depends_on = [
    talos_machine_bootstrap.cluster,
  ]
}

data "talos_cluster_kubeconfig" "cluster" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node = "10.10.0.10"
  endpoint = "dev-talos-cp-1:${var.control_plane_tunnel_ports[0]}"

  depends_on = [
    talos_machine_bootstrap.cluster,
  ]
}