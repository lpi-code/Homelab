# Development Environment - Terraform Variables
# Simplified variables with computed values using locals

# Required variables (no defaults - must be provided)
variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "storage_pool" {
  description = "Proxmox storage pool"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

# Core cluster configuration
variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
}

# Node configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
}

# Control plane configuration
variable "control_plane_vm_ids" {
  description = "VM IDs for control plane nodes"
  type        = list(number)
}

variable "control_plane_ips" {
  description = "Control plane IP addresses"
  type        = list(string)
}

variable "control_plane_cores" {
  description = "CPU cores for control plane nodes"
  type        = number
}

variable "control_plane_memory" {
  description = "Memory for control plane nodes (MB)"
  type        = number
}

variable "control_plane_disk_size" {
  description = "Control plane disk size"
  type        = string
}

# Worker configuration
variable "worker_vm_ids" {
  description = "VM IDs for worker nodes"
  type        = list(number)
}

variable "worker_ips" {
  description = "Worker IP addresses"
  type        = list(string)
}

variable "worker_cores" {
  description = "CPU cores for worker nodes"
  type        = number
}

variable "worker_memory" {
  description = "Memory for worker nodes (MB)"
  type        = number
}

variable "worker_disk_size" {
  description = "Worker disk size"
  type        = string
}

# Network configuration
variable "bridge_name" {
  description = "Network bridge name"
  type        = string
}

variable "talos_network_cidr" {
  description = "Talos network CIDR"
  type        = string
}

variable "talos_network_gateway" {
  description = "Talos network gateway"
  type        = string
}

variable "management_network_cidr" {
  description = "Management network CIDR"
  type        = string
}

variable "management_gateway" {
  description = "Management network gateway"
  type        = string
}

# NAT Gateway configuration
variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
}

variable "nat_gateway_vm_id" {
  description = "VM ID for NAT gateway"
  type        = number
}

variable "nat_gateway_management_ip" {
  description = "NAT gateway management IP"
  type        = string
}

variable "nat_gateway_cluster_ip" {
  description = "NAT gateway cluster IP"
  type        = string
}

variable "openwrt_version" {
  description = "OpenWrt version"
  type        = string
}

# Security configuration
variable "enable_firewall" {
  description = "Enable firewall"
  type        = bool
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
}

# Computed values using locals
locals {
  # Environment
  environment = "dev"
  
  # Proxmox configuration
  proxmox_user = "root@pam"
  proxmox_tls_insecure = true
  proxmox_api_url = "https://${var.proxmox_node}:8006/api2/json"
  
  # Tunnel configuration
  tunnel_local_port = 5801
  control_plane_tunnel_ports = [5802, 5803, 5804]
  worker_tunnel_ports = [5805, 5806, 5807]
  
  # Storage configuration
  iso_pool = "storage-isos"
  openwrt_template_file_id = "local:vztmpl/openwrt-template.tar.gz"
  talos_image_file_id = "storage-isos:import/talos.qcow2"
  
  # NAT Gateway defaults
  nat_gateway_password = "ChangeMe123!"
  nat_gateway_memory = 1024
  nat_gateway_cores = 1
}