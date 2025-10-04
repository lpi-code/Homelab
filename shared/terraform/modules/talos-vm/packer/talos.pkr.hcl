packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "bpg/proxmox"
    }
  }
}

variable "talos_version" {
  type        = string
  description = "Talos Linux version to build"
  default     = "1.9.5"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
  default     = "pve02"
}

variable "proxmox_storage_pool" {
  type        = string
  description = "Proxmox storage pool for the template"
  default     = "local-zfs"
}

variable "proxmox_iso_pool" {
  type        = string
  description = "Proxmox storage pool for ISOs"
  default     = "storage-isos"
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username"
  default     = "root@pam"
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
  default     = "https://pve02.homelab.local:8006/api2/json"
}

variable "template_name" {
  type        = string
  description = "Name for the created template"
  default     = "talos-linux"
}

variable "template_description" {
  type        = string
  description = "Description for the created template"
  default     = "Talos Linux template built with Packer"
}

variable "vm_memory" {
  type        = number
  description = "Memory for the build VM in MB"
  default     = 2048
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores for the build VM"
  default     = 2
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size for the build VM"
  default     = "20G"
}

variable "network_bridge" {
  type        = string
  description = "Network bridge for the build VM"
  default     = "vmbr0"
}

locals {
  talos_iso_url = "https://github.com/siderolabs/talos/releases/download/v${var.talos_version}/metal-amd64.iso"
  talos_iso_name = "talos-v${var.talos_version}-metal-amd64.iso"
  template_name_with_version = "${var.template_name}-v${var.talos_version}"
}

source "proxmox-iso" "talos" {
  # Proxmox connection settings
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true

  # VM settings
  node                 = var.proxmox_node
  vm_name              = local.template_name_with_version
  vm_id                = 9999
  memory               = var.vm_memory
  cores                = var.vm_cores
  cpu_type             = "host"
  machine              = "q35"
  bios                 = "seabios"
  scsi_controller      = "virtio-scsi-single"

  # Storage settings
  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.proxmox_storage_pool
    type         = "scsi"
    format       = "raw"
  }

  # Network settings
  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # ISO settings
  iso_file         = "${var.proxmox_iso_pool}:iso/${local.talos_iso_name}"
  iso_download_pve = true
  iso_url          = local.talos_iso_url
  iso_checksum     = "none"

  # Boot settings
  boot_wait = "10s"
  boot_command = [
    "talos",
    "<enter>"
  ]

  # Template settings
  template_name        = local.template_name_with_version
  template_description = "${var.template_description} - Version ${var.talos_version}"
  template_cloud_init = false

  # SSH settings (not used for Talos, but required by Packer)
  ssh_username = "root"
  ssh_password = "talos"
  ssh_timeout  = "20m"

  # Additional settings
  qemu_agent = true
  unmount_iso = true
}

build {
  name = "talos-template"
  sources = ["source.proxmox-iso.talos"]

  # Post-processing: Convert to template
  post-processor "shell-local" {
    inline = [
      "echo 'Template ${local.template_name_with_version} created successfully'"
    ]
  }
}


