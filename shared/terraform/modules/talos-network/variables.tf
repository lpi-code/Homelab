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
  description = "Gateway for the Talos cluster network (Proxmox bridge IP)"
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

# Firewall Configuration
variable "enable_firewall" {
  description = "Enable firewall rules for Talos cluster network"
  type        = bool
  default     = true
}
