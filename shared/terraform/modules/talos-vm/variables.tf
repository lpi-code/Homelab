# 🚀 Talos VM Module Variables
# Configuration variables for creating Talos VMs using direct qcow2 disk import

# 🖥️ Proxmox Configuration Variables
variable "proxmox_node" {
  type        = string
  description = "🖥️ Proxmox node name"
}

# Disk Image Configuration
variable "disk_image_file_id" {
  type        = string
  description = "📁 Full file ID for Proxmox VM disk configuration (datastore:filename)"
}

variable "storage_pool" {
  type        = string
  description = "💾 Proxmox storage pool for VM disks"
  default     = "local-zfs"
}

# 🚀 VM Configuration Variables
variable "vm_name" {
  description = "🏷️ Name of the VM (if null, will be generated)"
  type        = string
  default     = null
}

variable "vm_id" {
  description = "🆔 VM ID in Proxmox"
  type        = number
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "vm_disk_size" {
  description = "Disk size (e.g., '50G')"
  type        = string
  default     = "50G"
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "machine_type" {
  description = "Machine type"
  type        = string
  default     = "q35"
}

variable "bios_type" {
  description = "BIOS type"
  type        = string
  default     = "seabios"
}

variable "boot_order" {
  description = "Boot order"
  type        = list(string)
  default     = ["scsi0"]
}

# Note: proxmox_node and storage_pool are already defined above

# Network Configuration
variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_model" {
  description = "Network model"
  type        = string
  default     = "virtio"
}

variable "use_static_ip" {
  description = "Whether to use static IP configuration"
  type        = bool
  default     = true
}

variable "static_ip" {
  description = "Static IP address (required if use_static_ip is true)"
  type        = string
  default     = null
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = null
}

variable "network_cidr_suffix" {
  description = "Network CIDR suffix (e.g., '24' for /24)"
  type        = number
  default     = 24
}

# Talos Configuration
variable "cluster_name" {
  description = "Talos cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Talos cluster endpoint"
  type        = string
}

variable "node_type" {
  description = "Node type (controlplane or worker)"
  type        = string
  validation {
    condition     = contains(["controlplane", "worker"], var.node_type)
    error_message = "Node type must be either 'controlplane' or 'worker'."
  }
}

variable "node_index" {
  description = "Node index for naming"
  type        = number
  default     = 0
}

variable "machine_secrets" {
  description = "Talos machine secrets"
  type        = any
}

variable "client_configuration" {
  description = "Talos client configuration"
  type        = any
}

variable "config_patches" {
  description = "Talos configuration patches"
  type        = list(string)
  default     = []
}

# VM Behavior
variable "start_vm" {
  description = "Whether to start the VM after creation"
  type        = bool
  default     = true
}

variable "enable_qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}

variable "enable_disk_trim" {
  description = "Enable disk trim"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags for the VM"
  type        = list(string)
  default     = []
}

# Tunnel Configuration
variable "tunnel_local_port" {
  description = "Local port for SSH tunnel to this node"
  type        = number
  default     = null
}



