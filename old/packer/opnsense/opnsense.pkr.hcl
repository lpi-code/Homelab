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

variable "lan_ip" {
  type        = string
  description = "Static IP for OPNsense LAN interface (vtnet1) — becomes the cluster gateway"
  default     = "10.10.0.200"
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

  # No SSH communicator — vmbr0 (WAN bridge) has no IP on the Proxmox host so there
  # is no L3 path from the Packer builder to the VM. Config is applied via boot_command.
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

    "<wait300s>",

    # Login as root
    "root<enter>",
    "<wait5s>",
    "${var.root_password}<enter>",
    "<wait10s>",

    # Enter shell (option 8) to patch config.xml:
    #   1. Replace the default LAN IP (192.168.1.1) with the desired cluster gateway IP.
    #   2. Swap vtnet0 <-> vtnet1: OPNsense installer defaults to vtnet0=LAN, vtnet1=WAN,
    #      but Terraform creates NICs as vtnet0=WAN (management_bridge), vtnet1=LAN (cluster_bridge).
    #
    # Constraints:
    #   - Avoid <...> in commands — Packer treats angle brackets as special key sequences.
    #   - BSD sed requires explicit backup suffix: `sed -i ''` (not the Linux `sed -i`).
    "8<enter>",
    "<wait3s>",
    "sed -i '' 's/192.168.1.1/${var.lan_ip}/' /conf/config.xml<enter>",
    "<wait2s>",
    # Swap vtnet0 and vtnet1 so WAN=vtnet0 and LAN=vtnet1 matches the Terraform NIC order.
    # OPNsense installer default assigns vtnet0=LAN, vtnet1=WAN — opposite of what we need.
    # Three-step swap via placeholder to avoid overwriting both in a single pass.
    "sed -i '' 's/vtnet0/TMPNIC/' /conf/config.xml<enter>",
    "<wait2s>",
    "sed -i '' 's/vtnet1/vtnet0/' /conf/config.xml<enter>",
    "<wait2s>",
    "sed -i '' 's/TMPNIC/vtnet1/' /conf/config.xml<enter>",
    "<wait2s>",
    # Disable blockpriv and blockbogons on WAN — upstream is a private RFC1918 network
    # so these rules would drop DHCP responses and prevent WAN from getting an IP.
    "sed -i '' 's/blockpriv/blockprivDISABLED/' /conf/config.xml<enter>",
    "<wait2s>",
    "sed -i '' 's/blockbogons/blockbogonsDISABLED/' /conf/config.xml<enter>",
    "<wait2s>",
    "sync<enter>",
    "<wait2s>",
    "exit<enter>",
    "<wait2s>",

    # Power off cleanly (option 5 → confirm y)
    "5<enter>",
    "<wait5s>",
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
      "echo 'Template ${local.template_name} (VM ID: ${var.template_vm_id}) created successfully'",
      "echo 'LAN IP patched to: ${var.lan_ip} (cluster gateway)'",
    ]
  }
}
