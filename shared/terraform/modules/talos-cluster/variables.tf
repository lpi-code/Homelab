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
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.talos_version))
    error_message = "Talos version must be in format X.Y.Z (e.g., 1.9.5)."
  }
}

# Node Configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  validation {
    condition     = var.control_plane_count >= 1 && var.control_plane_count <= 5
    error_message = "Control plane count must be between 1 and 5."
  }
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
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
  validation {
    condition     = var.control_plane_cores >= 1 && var.control_plane_cores <= 32
    error_message = "Control plane cores must be between 1 and 32."
  }
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  validation {
    condition     = var.control_plane_memory >= 1024 && var.control_plane_memory <= 131072
    error_message = "Control plane memory must be between 1GB and 128GB."
  }
}

variable "control_plane_disk_size" {
  description = "Disk size for control plane nodes (e.g., '50G')"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+[GMK]?$", var.control_plane_disk_size))
    error_message = "Control plane disk size must be in format like '50G', '100G', etc."
  }
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
  validation {
    condition     = var.worker_cores >= 1 && var.worker_cores <= 32
    error_message = "Worker cores must be between 1 and 32."
  }
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  validation {
    condition     = var.worker_memory >= 1024 && var.worker_memory <= 131072
    error_message = "Worker memory must be between 1GB and 128GB."
  }
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes (e.g., '100G')"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+[GMK]?$", var.worker_disk_size))
    error_message = "Worker disk size must be in format like '100G', '200G', etc."
  }
}

# Network Configuration
variable "bridge_name" {
  description = "Name of the dedicated bridge for Talos cluster"
  type        = string
  validation {
    condition     = can(regex("^vmbr[0-9]+$", var.bridge_name))
    error_message = "Bridge name must be in format vmbrX (e.g., vmbr1, vmbr2)."
  }
}

variable "talos_network_cidr" {
  description = "CIDR for the Talos cluster network"
  type        = string
  validation {
    condition     = can(cidrhost(var.talos_network_cidr, 0))
    error_message = "Talos network CIDR must be a valid CIDR block."
  }
}

variable "talos_network_gateway" {
  description = "Gateway for the Talos cluster network"
  type        = string
  validation {
    condition     = can(cidrhost(var.talos_network_gateway, 0))
    error_message = "Talos network gateway must be a valid IP address."
  }
}

variable "management_network_cidr" {
  description = "CIDR for the management network"
  type        = string
  validation {
    condition     = can(cidrhost(var.management_network_cidr, 0))
    error_message = "Management network CIDR must be a valid CIDR block."
  }
}

variable "management_gateway" {
  description = "Gateway for the management network"
  type        = string
  validation {
    condition     = can(cidrhost(var.management_gateway, 0))
    error_message = "Management gateway must be a valid IP address."
  }
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT gateway for Talos cluster internet access"
  type        = bool
}

variable "nat_gateway_vm_id" {
  description = "VM ID for the NAT gateway"
  type        = number
  validation {
    condition     = var.nat_gateway_vm_id > 0 && var.nat_gateway_vm_id < 10000
    error_message = "NAT gateway VM ID must be between 1 and 9999."
  }
}

variable "nat_gateway_management_ip" {
  description = "Management IP for the NAT gateway (WAN interface)"
  type        = string
  validation {
    condition     = can(cidrhost(var.nat_gateway_management_ip, 0))
    error_message = "NAT gateway management IP must be a valid IP address with CIDR notation."
  }
}

variable "nat_gateway_cluster_ip" {
  description = "Cluster network IP for the NAT gateway (LAN interface)"
  type        = string
  validation {
    condition     = can(cidrhost(var.nat_gateway_cluster_ip, 0))
    error_message = "NAT gateway cluster IP must be a valid IP address with CIDR notation."
  }
}

variable "nat_gateway_password" {
  description = "Root password for OpenWrt NAT gateway"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.nat_gateway_password) >= 8
    error_message = "NAT gateway password must be at least 8 characters long."
  }
}

variable "openwrt_version" {
  description = "OpenWrt version to install"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.openwrt_version))
    error_message = "OpenWrt version must be in format X.Y.Z (e.g., 23.05.5)."
  }
}

variable "openwrt_template_file_id" {
  description = "Template file ID for the OpenWrt LXC container"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+:[a-zA-Z0-9_/.-]+$", var.openwrt_template_file_id))
    error_message = "OpenWrt template file ID must be in format 'pool:path'."
  }
}

variable "talos_image_file_id" {
  description = "File ID for the Talos image in Proxmox storage"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+:[a-zA-Z0-9_/.-]+$", var.talos_image_file_id))
    error_message = "Talos image file ID must be in format 'pool:path'."
  }
}

variable "iso_pool" {
  description = "Storage pool for ISO images"
  type        = string
  validation {
    condition     = length(var.iso_pool) > 0
    error_message = "ISO pool name cannot be empty."
  }
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for load balancer access"
  type        = list(string)
  validation {
    condition     = alltrue([for key in var.ssh_public_keys : can(regex("^ssh-", key))])
    error_message = "All SSH public keys must start with 'ssh-'."
  }
}

# Firewall Configuration
variable "enable_firewall" {
  description = "Enable firewall rules for Talos cluster network"
  type        = bool
}

# Tunnel Configuration
variable "control_plane_tunnel_ports" {
  description = "Local ports for control plane node tunnels"
  type        = list(number)
  validation {
    condition     = alltrue([for port in var.control_plane_tunnel_ports : port > 1024 && port < 65536])
    error_message = "All control plane tunnel ports must be between 1025 and 65535."
  }
}

variable "worker_tunnel_ports" {
  description = "Local ports for worker node tunnels"
  type        = list(number)
  validation {
    condition     = alltrue([for port in var.worker_tunnel_ports : port > 1024 && port < 65536])
    error_message = "All worker tunnel ports must be between 1025 and 65535."
  }
}


