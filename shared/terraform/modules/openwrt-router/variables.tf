# OpenWrt Router Module Variables

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
  description = "Name of the OpenWrt router VM"
  type        = string
  default     = "openwrt-router"
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
  default     = 512
}

variable "router_disk_size" {
  description = "Disk size for the router"
  type        = string
  default     = "1"
}

# Network Configuration
variable "management_bridge" {
  description = "Bridge for management network (WAN)"
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

variable "management_mac" {
  description = "MAC address for management interface"
  type        = string
  default     = ""
}

variable "cluster_mac" {
  description = "MAC address for cluster interface"
  type        = string
  default     = ""
}

# Template Configuration
variable "openwrt_template_file_id" {
  description = "Template file ID for the OpenWrt LXC container"
  type        = string
  default     = "local:vztmpl/openwrt-template.tar.gz"
}

variable "openwrt_version" {
  description = "OpenWrt version"
  type        = string
  default     = "23.05.5"
}

# VM Behavior
variable "auto_start" {
  description = "Auto-start the VM"
  type        = bool
  default     = true
}
