# 🚀 Talos VM Module

This Terraform module creates a single Talos VM from an existing template. It provides automatic Talos configuration generation and application for both control plane and worker nodes.

## ✨ Features

- 🖥️ **VM Creation**: Creates Talos VMs from existing templates
- 🎯 **Node Type Support**: Both control plane and worker nodes
- 🌐 **Network Configuration**: Static IP networking
- ⚙️ **Automatic Configuration**: Talos configuration generation and application
- 📝 **Beautiful Descriptions**: Emoji-enhanced VM descriptions
- 🔧 **Hardware Flexibility**: Configurable VM sizing and settings
- 🔐 **Security**: Automatic Talos machine configuration application

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                Talos VM Module                             │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Template VM      │  │ VM Creation      │                  │
│  │ • Existing       │  │ • Clone Template │                  │
│  │ • Talos Image    │  │ • Configure VM   │                  │
│  │ • Ready to Use   │  │ • Apply Talos    │                  │
│  └─────────────────┘  └─────────────────┘                  │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Proxmox VM       │  │ Talos Config    │                  │
│  │ • Hardware       │  │ • Machine Config│                  │
│  │ • Network        │  │ • Apply Config  │                  │
│  │ • Storage        │  │ • Ready to Use  │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example (Using Existing Template)

```hcl
module "talos_control_plane" {
  source = "./modules/talos-vm"

  # VM Configuration
  vm_name        = "talos-cp-1"
  vm_id          = 101
  template_vm_id = 100  # ID of existing template

  # Proxmox Configuration
  proxmox_node = "pve02"
  storage_pool = "local-zfs"

  # Network Configuration
  network_bridge      = "vmbr1"
  use_static_ip       = true
  static_ip          = "10.10.0.10"
  network_gateway    = "10.10.0.1"
  network_cidr_suffix = 24

  # Talos Configuration
  cluster_name     = "dev-cluster"
  cluster_endpoint = "https://10.10.0.10:6443"
  node_type        = "controlplane"
  node_index       = 0

  # Machine secrets and client configuration
  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  client_configuration = talos_machine_secrets.cluster.client_configuration

  # VM Resources
  vm_cores  = 2
  vm_memory = 4096
  vm_disk_size = "50G"
}
```

### Worker Node Example

```hcl
module "talos_worker" {
  source = "./modules/talos-vm"

  # VM Configuration
  vm_name        = "talos-worker-1"
  vm_id          = 201
  template_vm_id = 100  # ID of existing template

  # Proxmox Configuration
  proxmox_node = "pve02"
  storage_pool = "local-zfs"

  # Network Configuration
  network_bridge      = "vmbr1"
  use_static_ip       = true
  static_ip          = "10.10.0.20"
  network_gateway    = "10.10.0.1"
  network_cidr_suffix = 24

  # Talos Configuration
  cluster_name     = "dev-cluster"
  cluster_endpoint = "https://10.10.0.10:6443"
  node_type        = "worker"
  node_index       = 0

  # Machine secrets and client configuration
  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  client_configuration = talos_machine_secrets.cluster.client_configuration

  # VM Resources
  vm_cores  = 4
  vm_memory = 8192
  vm_disk_size = "100G"
}
```


## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| proxmox | >= 2.9.0 |
| talos | >= 1.9.0 |

## Providers

| Name | Version |
|------|---------|
| proxmox | >= 2.9.0 |
| talos | >= 1.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vm_name | Name of the VM (if null, will be generated) | `string` | `null` | no |
| vm_id | VM ID in Proxmox | `number` | n/a | yes |
| template_vm_id | Template VM ID to clone from | `number` | n/a | yes |
| vm_cores | Number of CPU cores | `number` | `2` | no |
| vm_memory | Memory in MB | `number` | `4096` | no |
| vm_disk_size | Disk size (e.g., '50G') | `string` | `"50G"` | no |
| cpu_type | CPU type | `string` | `"host"` | no |
| machine_type | Machine type | `string` | `"q35"` | no |
| bios_type | BIOS type | `string` | `"seabios"` | no |
| boot_order | Boot order | `list(string)` | `["scsi0"]` | no |
| proxmox_node | Proxmox node name | `string` | n/a | yes |
| storage_pool | Storage pool for VM disks | `string` | n/a | yes |
| network_bridge | Network bridge | `string` | `"vmbr0"` | no |
| network_model | Network model | `string` | `"virtio"` | no |
| use_static_ip | Whether to use static IP configuration | `bool` | `true` | no |
| static_ip | Static IP address (required if use_static_ip is true) | `string` | `null` | no |
| network_gateway | Network gateway | `string` | `null` | no |
| network_cidr_suffix | Network CIDR suffix (e.g., '24' for /24) | `number` | `24` | no |
| cluster_name | Talos cluster name | `string` | n/a | yes |
| cluster_endpoint | Talos cluster endpoint | `string` | n/a | yes |
| node_type | Node type (controlplane or worker) | `string` | n/a | yes |
| node_index | Node index for naming | `number` | `0` | no |
| machine_secrets | Talos machine secrets | `string` | n/a | yes |
| client_configuration | Talos client configuration | `string` | n/a | yes |
| config_patches | Talos configuration patches | `list(string)` | `[]` | no |
| start_vm | Whether to start the VM after creation | `bool` | `true` | no |
| enable_qemu_agent | Enable QEMU guest agent | `bool` | `true` | no |
| enable_disk_trim | Enable disk trim | `bool` | `true` | no |
| tags | Tags for the VM | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | VM ID in Proxmox |
| vm_name | VM name |
| vm_ipv4_address | VM IPv4 address |
| vm_mac_address | VM MAC address |
| vm_status | VM status |
| talos_node_ip | Talos node IP address for configuration |
| talos_machine_config | Generated Talos machine configuration |

## Prerequisites

1. **Talos template VM** - Pre-created Talos template VM (ID 100)
2. **Proxmox API access** - Configured with appropriate permissions
3. **Talos machine secrets** - Generated using `talos_machine_secrets` resource
4. **Network configuration** - Bridge and IP ranges properly configured

## Integration

This module is designed to work with:
- **talos-cluster module** - For complete cluster deployment
- **network module** - For network infrastructure
- **openwrt-router module** - For NAT gateway functionality

## Notes

- The module automatically generates and applies Talos machine configuration
- Static IP configuration is recommended for production deployments
- VM lifecycle ignores network and disk changes to prevent accidental modifications
- QEMU guest agent is enabled by default for better integration


