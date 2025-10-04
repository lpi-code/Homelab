# Network Module Variables

# Basic Configuration
variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for VMs"
  type        = string
}

# Bridge Configuration
variable "bridge_name" {
  description = "Name of the dedicated bridge for Talos cluster"
  type        = string
  default     = "vmbr1"
}

variable "bridge_ipv4_address" {
  description = "IPv4 address for the bridge (with CIDR)"
  type        = string
}

variable "bridge_ports" {
  description = "Bridge ports to attach"
  type        = string
  default     = ""
}

variable "bridge_vlan_aware" {
  description = "Enable VLAN awareness on the bridge"
  type        = bool
  default     = false
}

# Network Configuration
variable "talos_network_cidr" {
  description = "CIDR for the Talos cluster network"
  type        = string
}

variable "talos_network_gateway" {
  description = "Gateway for the Talos cluster network"
  type        = string
}

variable "management_network_cidr" {
  description = "CIDR for the management network"
  type        = string
}

variable "management_gateway" {
  description = "Gateway for the management network"
  type        = string
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT gateway for Talos cluster internet access"
  type        = bool
  default     = true
}

variable "nat_gateway_vm_id" {
  description = "VM ID for the NAT gateway"
  type        = number
  default     = 200
}

variable "nat_gateway_management_ip" {
  description = "Management IP for the NAT gateway (WAN interface)"
  type        = string
}

variable "nat_gateway_cluster_ip" {
  description = "Cluster network IP for the NAT gateway (LAN interface)"
  type        = string
}

variable "nat_gateway_password" {
  description = "Root password for OpenWrt NAT gateway"
  type        = string
  default     = "openwrt"
  sensitive   = true
}

variable "openwrt_version" {
  description = "OpenWrt version to install"
  type        = string
  default     = "23.05.5"
}

variable "openwrt_template_file_id" {
  description = "Template file ID for the OpenWrt LXC container"
  type        = string
  default     = "local:vztmpl/openwrt-template.tar.gz"
}

variable "iso_pool" {
  description = "Storage pool for ISO images"
  type        = string
  default     = "local"
}

variable "talos_control_plane_ips" {
  description = "List of control plane IP addresses for load balancing"
  type        = list(string)
  default     = []
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for load balancer access"
  type        = list(string)
  default     = []
}

# Firewall Configuration
variable "enable_firewall" {
  description = "Enable firewall rules for Talos cluster network"
  type        = bool
  default     = true
}


