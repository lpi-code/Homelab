# Talos VM Template Packer Configuration
# This configuration creates a Talos Linux VM template for Proxmox

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variables from Ansible inventory
variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_user" {
  type        = string
  description = "Proxmox username"
}

variable "proxmox_password" {
  type        = string
  description = "Proxmox password"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name"
}

variable "proxmox_storage_pool" {
  type        = string
  description = "Proxmox storage pool"
  default     = "storage-vms"
}

variable "talos_version" {
  type        = string
  description = "Talos Linux version"
  default     = "1.8.0"
}

variable "vm_memory" {
  type        = number
  description = "VM memory in MB"
  default     = 2048
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "vm_disk_size" {
  type        = string
  description = "VM disk size"
  default     = "20G"
}

variable "vm_network_bridge" {
  type        = string
  description = "VM network bridge"
  default     = "vmbr0"
}

# Talos VM Template Build
source "proxmox" "talos_template" {
  # Proxmox connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_user
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  
  # VM Configuration
  node                 = var.proxmox_node
  vm_id                = 9999  # Template VM ID
  vm_name              = "talos-template"
  template_description = "Talos Linux template for Kubernetes clusters"
  
  # VM Resources
  memory               = var.vm_memory
  cores                = var.vm_cores
  sockets              = 1
  cpu_type             = "host"
  
  # Network Configuration
  network_adapters {
    model  = "virtio"
    bridge = var.vm_network_bridge
  }
  
  # Disk Configuration
  disks {
    type         = "scsi"
    storage_pool = var.proxmox_storage_pool
    storage_pool_type = "zfs"
    disk_size    = var.vm_disk_size
    format       = "qcow2"
  }
  
  # Cloud-init configuration
  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage_pool
  
  # ISO Configuration for Talos
  iso_file         = "local:iso/talos-amd64.iso"
  iso_storage_pool = "storage-isos"
  
  # Boot configuration
  boot_wait = "10s"
  boot_command = [
    "talos",
    "<enter>"
  ]
  
  # SSH configuration for provisioning
  ssh_username = "talos"
  ssh_timeout  = "20m"
  
  # Template configuration
  template_name        = "talos-template"
  template_description = "Talos Linux template for Kubernetes clusters"
  
  # Additional configuration
  qemu_agent = true
  scsi_controller = "virtio-scsi-pci"
}

# Build configuration
build {
  name = "talos-template"
  
  sources = ["source.proxmox.talos_template"]
  
  # Provisioning steps
  provisioner "shell" {
    inline = [
      "echo 'Talos Linux template provisioning completed'",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent"
    ]
  }
  
  # Post-processing
  post-processor "manifest" {
    output = "talos-template-manifest.json"
  }
}