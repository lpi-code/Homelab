# 🚀 Provider Version Requirements for Talos Cluster
# Defines the required providers and their versions

terraform {
  required_version = ">= 1.0"
  
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

# Provider Configuration
# bpg/proxmox provider uses environment variables for configuration
# Set these environment variables:
# PROXMOX_VE_ENDPOINT, PROXMOX_VE_USERNAME, PROXMOX_VE_PASSWORD, PROXMOX_VE_INSECURE
provider "proxmox" {
  # Configuration is done via environment variables
  # PROXMOX_VE_ENDPOINT, PROXMOX_VE_USERNAME, PROXMOX_VE_PASSWORD, PROXMOX_VE_INSECURE
}

provider "talos" {
  # Talos provider doesn't require explicit configuration
}

