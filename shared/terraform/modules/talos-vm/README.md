# Talos VM Module

This Terraform module creates a single Talos VM from a disk image. It provides automatic Talos configuration generation and application for both control plane and worker nodes.

## Features

- VM creation from Talos qcow2 disk image
- Both control plane and worker node support
- Static IP networking
- Automatic Talos machine configuration generation and application
- Configurable VM sizing and hardware settings
- QEMU guest agent support

## Usage

### Control Plane Node

```hcl
module "talos_control_plane" {
  source = "./modules/talos-vm"

  # VM Configuration
  vm_name        = "talos-cp-1"
  vm_id          = 101

  # Disk image
  disk_image_file_id = "storage-isos:import/talos.qcow2"

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
  vm_cores     = 2
  vm_memory    = 4096
  vm_disk_size = "50G"
}
```

### Worker Node

```hcl
module "talos_worker" {
  source = "./modules/talos-vm"

  vm_name        = "talos-worker-1"
  vm_id          = 201

  disk_image_file_id = "storage-isos:import/talos.qcow2"

  proxmox_node = "pve02"
  storage_pool = "local-zfs"

  network_bridge      = "vmbr1"
  use_static_ip       = true
  static_ip          = "10.10.0.20"
  network_gateway    = "10.10.0.1"
  network_cidr_suffix = 24

  cluster_name     = "dev-cluster"
  cluster_endpoint = "https://10.10.0.10:6443"
  node_type        = "worker"
  node_index       = 0

  machine_secrets      = talos_machine_secrets.cluster.machine_secrets
  client_configuration = talos_machine_secrets.cluster.client_configuration

  vm_cores     = 4
  vm_memory    = 8192
  vm_disk_size = "100G"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| proxmox | >= 2.9.0 |
| talos | >= 1.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vm_name | Name of the VM | `string` | `null` | no |
| vm_id | VM ID in Proxmox | `number` | n/a | yes |
| disk_image_file_id | Talos disk image file ID | `string` | n/a | yes |
| vm_cores | Number of CPU cores | `number` | `2` | no |
| vm_memory | Memory in MB | `number` | `4096` | no |
| vm_disk_size | Disk size (e.g., '50G') | `string` | `"50G"` | no |
| proxmox_node | Proxmox node name | `string` | n/a | yes |
| storage_pool | Storage pool for VM disks | `string` | n/a | yes |
| network_bridge | Network bridge | `string` | `"vmbr0"` | no |
| use_static_ip | Use static IP configuration | `bool` | `true` | no |
| static_ip | Static IP address | `string` | `null` | no |
| network_gateway | Network gateway | `string` | `null` | no |
| network_cidr_suffix | Network CIDR suffix | `number` | `24` | no |
| cluster_name | Talos cluster name | `string` | n/a | yes |
| cluster_endpoint | Talos cluster endpoint | `string` | n/a | yes |
| node_type | Node type (controlplane or worker) | `string` | n/a | yes |
| node_index | Node index for naming | `number` | `0` | no |
| machine_secrets | Talos machine secrets | `string` | n/a | yes |
| client_configuration | Talos client configuration | `string` | n/a | yes |
| config_patches | Talos configuration patches | `list(string)` | `[]` | no |
| tags | Tags for the VM | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | VM ID in Proxmox |
| vm_name | VM name |
| vm_ipv4_address | VM IPv4 address |
| vm_mac_address | VM MAC address |
| vm_status | VM status |

## Integration

This module is designed to work with:
- **talos-cluster module** — orchestrates complete cluster deployment
- **talos-network module** — manages firewall rules

## Notes

- Static IP configuration is recommended for production deployments
- VM lifecycle ignores network and disk changes to prevent accidental modifications
- QEMU guest agent is enabled by default
