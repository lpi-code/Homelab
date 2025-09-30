# Development Environment - Terraform Variables
# This file defines all variables for the dev environment

# Environment configuration
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Target host configuration
variable "target_host" {
  description = "Target host name from Ansible inventory"
  type        = string
}

variable "create_vm" {
  description = "Whether to create the VM"
  type        = bool
  default     = true
}

# Proxmox configuration
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

# Cloud-init configuration
variable "cloud_init_user" {
  description = "Cloud-init default user"
  type        = string
  default     = "root"
}

variable "cloud_init_password" {
  description = "Cloud-init default password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}

# Network configuration
variable "network_cidr" {
  description = "Network CIDR block"
  type        = string
  default     = "192.168.1.0/24"
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.1.1", "8.8.8.8"]
}

# VM configuration overrides
variable "vm_memory_override" {
  description = "Override VM memory from Ansible"
  type        = number
  default     = null
}

variable "vm_cores_override" {
  description = "Override VM cores from Ansible"
  type        = number
  default     = null
}

variable "vm_disk_size_override" {
  description = "Override VM disk size from Ansible"
  type        = string
  default     = null
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = list(string)
  default     = []
}

# Environment-specific variables
variable "dev_specific_config" {
  description = "Development-specific configuration"
  type        = map(string)
  default = {
    backup_enabled = "true"
    monitoring_enabled = "true"
    debug_mode = "true"
  }
}
