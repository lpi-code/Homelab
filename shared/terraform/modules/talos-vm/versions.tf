# Provider Version Requirements for Talos VM Module

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
  }
}
