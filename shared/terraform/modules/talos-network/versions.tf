# Provider Version Requirements for Talos Network Module

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63"
    }
  }
}
