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
  default     = ""
}

# OpenWrt configuration
variable "openwrt_filename" {
  description = "OpenWrt image filename"
  type        = string
  default     = "openwrt-23.05.5-x86-64-efi.img"
}


# Additional missing variables

variable "control_plane_ips" {
  description = "Control plane IP addresses"
  type        = list(string)
  default     = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
}

variable "control_plane_disk_size" {
  description = "Control plane disk size"
  type        = string
  default     = "50G"
}

variable "worker_ips" {
  description = "Worker IP addresses"
  type        = list(string)
  default     = ["10.10.0.20", "10.10.0.21", "10.10.0.22"]
}

variable "worker_disk_size" {
  description = "Worker disk size"
  type        = string
  default     = "50G"
}

variable "bridge_name" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr1"
}

variable "talos_network_gateway" {
  description = "Talos network gateway"
  type        = string
  default     = "10.10.0.1"
}

variable "management_network_cidr" {
  description = "Management network CIDR"
  type        = string
  default     = "192.168.0.0/24"
}

variable "management_gateway" {
  description = "Management network gateway"
  type        = string
  default     = "192.168.0.1"
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "nat_gateway_management_ip" {
  description = "NAT gateway management IP"
  type        = string
  default     = "192.168.0.200/24"
}

variable "nat_gateway_cluster_ip" {
  description = "NAT gateway cluster IP"
  type        = string
  default     = "10.10.0.200/24"
}

variable "nat_gateway_password" {
  description = "NAT gateway password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "openwrt_version" {
  description = "OpenWrt version"
  type        = string
  default     = "23.05.5"
}

variable "iso_pool" {
  description = "ISO storage pool"
  type        = string
  default     = "storage-isos"
}

variable "enable_firewall" {
  description = "Enable firewall"
  type        = bool
  default     = true
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
  default     = []
}


variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.0.149:8006/"
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "k8s_cni" {
  description = "Kubernetes CNI"
  type        = string
  default     = "flannel"
}

variable "k8s_pod_cidr" {
  description = "Kubernetes pod CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  description = "Kubernetes service CIDR"
  type        = string
  default     = "10.96.0.0/12"
}

variable "tunnel_local_port" {
  description = "Local port for SSH tunnel"
  type        = number
  default     = 5801
}

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

variable "openwrt_template_file_id" {
  description = "OpenWrt template file ID for LXC container"
  type        = string
  default     = "local:vztmpl/openwrt-template.tar.gz"
}

variable "talos_image_file_id" {
  description = "Talos image file ID"
  type        = string
  default     = "storage-isos:import/talos.qcow2"
}