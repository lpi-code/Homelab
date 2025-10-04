# 🌐 Talos Network Infrastructure Module
# Creates network infrastructure including bridges and firewall rules with NAT
# Built with ❤️ for Kubernetes homelab infrastructure

# 🔧 Local Variables & Network Configuration
locals {
  # 🌐 Network configuration calculations
  bridge_ipv4_cidr = "${var.bridge_ipv4_address}/${split("/", var.talos_network_cidr)[1]}"
  netmask = cidrnetmask(var.talos_network_cidr)
  net_cidr_suffix = split("/", var.talos_network_cidr)[1]
}

# 🌉 Create Dedicated Bridge for Talos Cluster
resource "proxmox_virtual_environment_network_linux_bridge" "talos_bridge" {
  node_name = var.proxmox_node
  name      = var.bridge_name
  comment   = "🌐 Dedicated bridge for ${var.cluster_name} Talos cluster"

  # 🌉 Bridge Configuration
  # Note: bridge_ports and bridge_vlan_aware are not supported by the provider
  
  # 🔗 IP Configuration
  address = var.bridge_ipv4_address
  # Note: gateway removed - only one default gateway allowed per node (vmbr0 already has it)
  
  # ⚙️ Additional Settings
  autostart = true
}

# 🌐 Create NAT Gateway using OpenWrt Router Module
module "openwrt_router" {
  count = var.enable_nat_gateway ? 1 : 0
  source = "../openwrt-router"

  # Basic Configuration
  proxmox_node = var.proxmox_node
  cluster_name = var.cluster_name
  storage_pool = var.storage_pool

  # Router Configuration
  router_name = "${var.cluster_name}-openwrt"
  router_vm_id = var.nat_gateway_vm_id
  router_cpu_cores = 1
  router_memory = 512
  router_disk_size = "1"

  # Network Configuration
  management_bridge = "vmbr0"  # Management/WAN bridge
  cluster_bridge = proxmox_virtual_environment_network_linux_bridge.talos_bridge.name
  management_ip = var.nat_gateway_management_ip
  cluster_ip = var.nat_gateway_cluster_ip
  management_gateway = var.management_gateway

  # Template Configuration
  openwrt_template_file_id = var.openwrt_template_file_id

  # VM Behavior
  auto_start = true

  depends_on = [
    proxmox_virtual_environment_network_linux_bridge.talos_bridge,
  ]
}

# Create firewall rules if enabled
resource "proxmox_virtual_environment_firewall_rules" "talos_cluster" {
  count = var.enable_firewall ? 1 : 0
  
  node_name = var.proxmox_node

  # Allow Talos API access
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Talos API access"
    dest    = var.talos_network_cidr
    dport   = "50000"
    proto   = "tcp"
  }

  # Allow Kubernetes API access
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubernetes API access"
    dest    = var.talos_network_cidr
    dport   = "6443"
    proto   = "tcp"
  }

  # Allow etcd peer access (port 2379)
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow etcd client access"
    dest    = var.talos_network_cidr
    dport   = "2379"
    proto   = "tcp"
  }

  # Allow etcd peer access (port 2380)
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow etcd peer access"
    dest    = var.talos_network_cidr
    dport   = "2380"
    proto   = "tcp"
  }

  # Allow node-to-node communication
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow node-to-node communication"
    source  = var.talos_network_cidr
    dest    = var.talos_network_cidr
    proto   = "tcp"
  }

  # Allow UDP for node-to-node communication
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow UDP node-to-node communication"
    source  = var.talos_network_cidr
    dest    = var.talos_network_cidr
    proto   = "udp"
  }

  # Allow NAT gateway access
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow NAT gateway access"
    source  = var.management_network_cidr
    dest    = var.talos_network_cidr
    proto   = "tcp"
  }

  depends_on = [
    proxmox_virtual_environment_network_linux_bridge.talos_bridge
  ]
}


