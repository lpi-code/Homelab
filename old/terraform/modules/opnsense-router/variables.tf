# OPNsense Router Module Variables

# Basic Configuration
variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster this router serves"
  type        = string
}

variable "storage_pool" {
  description = "Storage pool for VMs"
  type        = string
}

# Router Configuration
variable "router_name" {
  description = "Name of the OPNsense router VM"
  type        = string
  default     = "opnsense-router"
}

variable "router_vm_id" {
  description = "VM ID for the router"
  type        = number
  default     = 200
}

variable "router_cpu_cores" {
  description = "Number of CPU cores for the router"
  type        = number
  default     = 1
}

variable "router_memory" {
  description = "Memory for the router in MB"
  type        = number
  default     = 1024
}

# Template Configuration
variable "opnsense_template_vm_id" {
  description = "VM ID of the OPNsense Packer-built template to clone from"
  type        = number
  default     = 9000
}

# Network Configuration
variable "management_bridge" {
  description = "Linux bridge for WAN interface (must be a proper Linux bridge, not a physical NIC)"
  type        = string
  default     = "vmbr0"
}

variable "cluster_bridge" {
  description = "Bridge for cluster network (LAN)"
  type        = string
  default     = "vmbr1"
}

variable "management_ip" {
  description = "Management IP address for the router (WAN)"
  type        = string
}

variable "cluster_ip" {
  description = "Cluster IP address for the router (LAN)"
  type        = string
}

variable "management_gateway" {
  description = "Gateway for management network"
  type        = string
}

# VM Behavior
variable "auto_start" {
  description = "Auto-start the VM on boot"
  type        = bool
  default     = true
}
