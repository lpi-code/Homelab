# Packer variables for Talos template building
# This file can be overridden with a variables file or environment variables

# Talos version to build
talos_version = "1.9.5"

# Proxmox connection settings
proxmox_node = "pve02"
proxmox_storage_pool = "local-zfs"
proxmox_iso_pool = "storage-isos"
proxmox_username = "root@pam"
proxmox_url = "https://pve02.homelab.local:8006/api2/json"

# Template settings
template_name = "talos-linux"
template_description = "Talos Linux template built with Packer"

# Build VM settings
vm_memory = 2048
vm_cores = 2
vm_disk_size = "20G"
network_bridge = "vmbr0"


