# OPNsense Router Module
# Creates OPNsense router VM from Packer-built template

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63"
    }
  }
}

# Create VM by cloning the OPNsense template
resource "proxmox_virtual_environment_vm" "opnsense_router" {
  node_name = var.proxmox_node
  vm_id     = var.router_vm_id
  name      = var.router_name

  clone {
    vm_id = var.opnsense_template_vm_id
    full  = true
  }

  cpu {
    cores = var.router_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.router_memory
  }


  # WAN interface (management network) — vtnet0
  network_device {
    bridge = var.management_bridge
    model  = "virtio"
  }

  # LAN interface (cluster network) — vtnet1
  network_device {
    bridge = var.cluster_bridge
    model  = "virtio"
  }
  operating_system {
    type = "other"
  }

  on_boot = var.auto_start
  started = true

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}
