# Development Environment - Terraform Variables
# This file defines all variables for the dev environment

# Proxmox configuration
variable "proxmox_host" {
  description = "Proxmox host IP address or hostname"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

# Cluster configuration
variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "talos-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VM configuration
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

# VM IDs - these will be checked against existing VMs
variable "control_plane_vm_ids" {
  description = "VM IDs for control plane nodes"
  type        = list(number)
  default     = [101, 102, 103]
}

variable "worker_vm_ids" {
  description = "VM IDs for worker nodes"
  type        = list(number)
  default     = [201, 202, 203]
}

variable "nat_gateway_vm_id" {
  description = "VM ID for NAT gateway"
  type        = number
  default     = 200
}

# VM specifications
variable "control_plane_memory" {
  description = "Memory for control plane nodes (MB)"
  type        = number
  default     = 4096
}

variable "control_plane_cores" {
  description = "CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Memory for worker nodes (MB)"
  type        = number
  default     = 8192
}

variable "worker_cores" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "nat_gateway_memory" {
  description = "Memory for NAT gateway (MB)"
  type        = number
  default     = 1024
}

variable "nat_gateway_cores" {
  description = "CPU cores for NAT gateway"
  type        = number
  default     = 1
}

# Storage configuration
variable "storage_pool" {
  description = "Proxmox storage pool"
  type        = string
}

variable "vm_disk_size" {
  description = "VM disk size"
  type        = string
  default     = "32G"
}

# Network configuration
variable "talos_network_cidr" {
  description = "Talos network CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "nat_gateway_enabled" {
  description = "Whether to enable NAT gateway"
  type        = bool
  default     = false
}

# Talos configuration
variable "talos_version" {
  description = "Talos version"
  type        = string
  default     = "v1.7.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.29.0"
}

# SSH configuration
variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}

# OpenWrt configuration
variable "openwrt_filename" {
  description = "OpenWrt image filename"
  type        = string
  default     = "openwrt-23.05.5-x86-64-efi.img"
}
