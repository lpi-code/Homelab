# Talos Network Infrastructure Module
# Creates network infrastructure including firewall rules.
# NAT is handled by Proxmox iptables masquerade on vmbr1 (configured by 03a-preflight).

# Local Variables & Network Configuration
locals {
  # Network configuration calculations
  bridge_ipv4_cidr = "${var.bridge_ipv4_address}/${split("/", var.talos_network_cidr)[1]}"
  netmask = cidrnetmask(var.talos_network_cidr)
  net_cidr_suffix = split("/", var.talos_network_cidr)[1]
}

# Bridge vmbr1 is created by 03a-preflight.ansible.yml before Terraform runs.
# Terraform only manages what runs ON the bridge (VMs, firewall), not the bridge itself.

# Create firewall rules if enabled
resource "proxmox_virtual_environment_firewall_rules" "talos_cluster" {
  count = var.enable_firewall ? 1 : 0

  node_name = var.proxmox_node

  # Allow Talos API access from management network only
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Talos API access from management network"
    source  = var.management_network_cidr
    dest    = var.talos_network_cidr
    dport   = "50000"
    proto   = "tcp"
  }

  # Allow Kubernetes API access from management and cluster networks
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubernetes API access from management network"
    source  = var.management_network_cidr
    dest    = var.talos_network_cidr
    dport   = "6443"
    proto   = "tcp"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow Kubernetes API access within cluster"
    source  = var.talos_network_cidr
    dest    = var.talos_network_cidr
    dport   = "6443"
    proto   = "tcp"
  }

  # Allow etcd access within cluster only
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow etcd client access within cluster"
    source  = var.talos_network_cidr
    dest    = var.talos_network_cidr
    dport   = "2379"
    proto   = "tcp"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Allow etcd peer access within cluster"
    source  = var.talos_network_cidr
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

}
