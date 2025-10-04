# Talos Cluster Module Variables

# Basic Configuration
variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for VMs"
  type        = string
}

# Talos Configuration
variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "1.9.5"
}

# Node Configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.control_plane_count >= 1 && var.control_plane_count <= 5
    error_message = "Control plane count must be between 1 and 5."
  }
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.worker_count >= 0
    error_message = "Worker count must be 0 or greater."
  }
}

# Control Plane Configuration
variable "control_plane_ips" {
  description = "List of control plane IP addresses"
  type        = list(string)
}

variable "control_plane_vm_ids" {
  description = "List of control plane VM IDs"
  type        = list(number)
}

variable "control_plane_cores" {
  description = "Number of CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 4096
}

variable "control_plane_disk_size" {
  description = "Disk size for control plane nodes (e.g., '50G')"
  type        = string
  default     = "50G"
}

# Worker Configuration
variable "worker_ips" {
  description = "List of worker IP addresses"
  type        = list(string)
}

variable "worker_vm_ids" {
  description = "List of worker VM IDs"
  type        = list(number)
}

variable "worker_cores" {
  description = "Number of CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 8192
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes (e.g., '100G')"
  type        = string
  default     = "100G"
}

# Network Configuration
variable "bridge_name" {
  description = "Name of the dedicated bridge for Talos cluster"
  type        = string
  default     = "vmbr1"
}

variable "talos_network_cidr" {
  description = "CIDR for the Talos cluster network"
  type        = string
  default     = "10.10.0.0/24"
}

variable "talos_network_gateway" {
  description = "Gateway for the Talos cluster network"
  type        = string
  default     = "10.10.0.1"
}

variable "management_network_cidr" {
  description = "CIDR for the management network"
  type        = string
  default     = "192.168.0.0/24"
}

variable "management_gateway" {
  description = "Gateway for the management network"
  type        = string
  default     = "192.168.0.1"
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
  default     = "192.168.0.200/24"
}

variable "nat_gateway_cluster_ip" {
  description = "Cluster network IP for the NAT gateway (LAN interface)"
  type        = string
  default     = "10.10.0.200/24"
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

variable "talos_image_file_id" {
  description = "File ID for the Talos image in Proxmox storage"
  type        = string
  default     = "local:iso/talos.qcow2"
}

variable "iso_pool" {
  description = "Storage pool for ISO images"
  type        = string
  default     = "local"
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

# Tunnel Configuration
variable "control_plane_tunnel_ports" {
  description = "Local ports for control plane node tunnels"
  type        = list(number)
  default     = [5802, 5803, 5804]
}

variable "worker_tunnel_ports" {
  description = "Local ports for worker node tunnels"
  type        = list(number)
  default     = [5805, 5806, 5807]
}


