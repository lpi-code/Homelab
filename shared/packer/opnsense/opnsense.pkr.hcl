packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "opnsense_version" {
  type        = string
  description = "OPNsense version to build"
  default     = "26.1"
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
  default     = ""
}

variable "proxmox_password" {
  type        = string
  description = "Proxmox password (used if token is empty)"
  sensitive   = true
  default     = ""
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
  default     = "https://pve02.homelab.local:8006/api2/json"
}

variable "template_vm_id" {
  type        = number
  description = "VM ID for the OPNsense template"
  default     = 9000
}

variable "vm_memory" {
  type        = number
  description = "Memory for the build VM in MB"
  default     = 4096
}

variable "vm_cores" {
  type        = number
  description = "Number of CPU cores for the build VM"
  default     = 2
}

variable "vm_disk_size" {
  type        = string
  description = "Disk size for the build VM"
  default     = "30G"
}

variable "network_bridge" {
  type        = string
  description = "Network bridge for the build VM"
  default     = "vmbr0"
}

variable "root_password" {
  type        = string
  description = "Root password for OPNsense"
  sensitive   = true
  default     = "opnsense"
}

locals {
  iso_name      = "OPNsense-${var.opnsense_version}-dvd-amd64.iso"
  template_name = "opnsense-${var.opnsense_version}"
}

source "proxmox-iso" "opnsense" {
  # Proxmox connection settings
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true

  # VM settings
  node       = var.proxmox_node
  vm_name    = local.template_name
  vm_id      = var.template_vm_id
  memory     = var.vm_memory
  cores      = var.vm_cores
  cpu_type   = "host"
  machine    = "q35"
  os         = "other"
  bios       = "seabios"
  scsi_controller = "virtio-scsi-single"

  # Disk
  disks {
    disk_size    = var.vm_disk_size
    storage_pool = var.proxmox_storage_pool
    type         = "scsi"
    format       = "raw"
  }

  # WAN NIC
  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # LAN NIC
  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # ISO: Proxmox directory storage expects volume name "iso/<filename>" (maps to template/iso/<filename> on disk)
  boot_iso {
    type     = "ide"
    index    = "2"
    iso_file = "${var.proxmox_iso_pool}:iso/${local.iso_name}"
    unmount  = true
  }

  # Boot order: disk first (falls through to CD on empty disk)
  boot = "order=scsi0;ide2"

  # No SSH - OPNsense doesn't enable SSH by default
  communicator = "none"

  # Boot command to automate the OPNsense DVD installer
  boot_wait = "480s"
  boot_command = [
    # Login as installer at the DVD boot prompt
    "installer<enter>",
    "<wait2s>",
    "opnsense<enter>",
    "<wait5s>",

    # Accept default keymap - select Continue
    "<enter>",
    "<wait5s>",


    # Select "Install (ZFS)" (default selection)
    "<enter>",
    "<wait10s>",

    ## Skip mem warning
    #"<enter>",
    #"<wait5s>",

    # Select stripe
    "<enter>",
    "<wait5s>",

    # Select disk (space to mark vtbd0, enter to continue)
    "<spacebar><enter>",
    "<wait5s>",

    # Confirm disk wipe - navigate to Yes
    "<left><enter>",
    "<wait680s>",


    "<enter>",
    "<down>",
    # Set root password
    "${var.root_password}<enter>",
    "<wait2s>",
    "${var.root_password}<enter>",

    # Complete Install (triggers reboot)
    "<enter>",
    "<wait400s>",



    # Set root password
    "<enter><wait5s>",
    "${var.root_password}<enter>",
    "<wait5s>",
    "${var.root_password}<enter>",
    "<wait15s>",

    # Complete install
    "<down>,<enter>",
    "<wait5s>",
    "<enter>",

    "<wait60s>",

    # Login as root
    "root<enter>",
    "<wait5s>",
    "${var.root_password}<enter>",
    "<wait5s>",

    # Power off from console menu (option 5)
    "5<enter>",
    "<wait5s>",
    # Confirm power off
    "y<enter>",
    "<wait60s>",
  ]

  # Template settings
  template_name        = local.template_name
  template_description = "OPNsense ${var.opnsense_version} template built with Packer"
  qemu_agent = false
}

build {
  name    = "opnsense-template"
  sources = ["source.proxmox-iso.opnsense"]

  post-processor "shell-local" {
    inline = [
      "echo 'Template ${local.template_name} (VM ID: ${var.template_vm_id}) created successfully'"
    ]
  }
}
