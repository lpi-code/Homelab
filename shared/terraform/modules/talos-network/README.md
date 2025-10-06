# 🌐 Talos Network Module

This Terraform module creates network infrastructure for a Talos Kubernetes cluster on Proxmox, including dedicated bridges, fully automated OpenWrt NAT gateway, and firewall rules.

## ✨ Features

- 🌉 Creates dedicated network bridge for Talos cluster
- 🌐 **Fully Automated OpenWrt Router** with zero manual configuration
- 🔧 Automatic network configuration via SSH (WAN/LAN setup)
- 🔥 Built-in firewall with NAT masquerading
- 🔥 Configurable firewall rules for cluster security
- 🌐 Support for both management and cluster networks
- 🚀 Automatic NAT gateway configuration for internet access
- 📝 Beautiful emoji-based VM descriptions for quick identification
- 🔐 SSH tunnel support for remote access

## Usage

### Basic Example

```hcl
module "talos_network" {
  source = "./modules/talos-network"

  # Basic configuration
  proxmox_node = "pve02"
  cluster_name = "dev-cluster"
  storage_pool = "local-zfs"

  # Bridge configuration
  bridge_name = "vmbr1"
  bridge_ipv4_address = "10.10.0.1/24"

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # OpenWrt NAT gateway configuration
  enable_nat_gateway = true
  nat_gateway_vm_id = 200
  nat_gateway_management_ip = "192.168.0.200"
  nat_gateway_cluster_ip = "10.10.0.200"  # Gateway for Talos cluster
  nat_gateway_password = "ChangeMe123!"  # OpenWrt root password
  openwrt_version = "23.05.5"  # OpenWrt version to install
  iso_pool = "storage-isos"  # Storage pool for OpenWrt image

  # Firewall configuration
  enable_firewall = true
}
```

### Without NAT Gateway

```hcl
module "talos_network" {
  source = "./modules/talos-network"

  # Basic configuration
  proxmox_node = "pve02"
  cluster_name = "dev-cluster"
  storage_pool = "local-zfs"

  # Bridge configuration
  bridge_name = "vmbr1"
  bridge_ipv4_address = "10.10.0.1/24"

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # Disable NAT gateway
  enable_nat_gateway = false

  # Firewall configuration
  enable_firewall = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| proxmox | >= 2.9.0 |

## Providers

| Name | Version |
|------|---------|
| proxmox | >= 2.9.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| proxmox_node | Proxmox node name | `string` | n/a | yes |
| cluster_name | Name of the Talos cluster | `string` | n/a | yes |
| storage_pool | Storage pool for VMs | `string` | n/a | yes |
| bridge_name | Name of the dedicated bridge for Talos cluster | `string` | `"vmbr1"` | no |
| bridge_ipv4_address | IPv4 address for the bridge (with CIDR) | `string` | n/a | yes |
| bridge_ports | Bridge ports to attach | `string` | `""` | no |
| bridge_vlan_aware | Enable VLAN awareness on the bridge | `bool` | `false` | no |
| talos_network_cidr | CIDR for the Talos cluster network | `string` | n/a | yes |
| talos_network_gateway | Gateway for the Talos cluster network | `string` | n/a | yes |
| management_network_cidr | CIDR for the management network | `string` | n/a | yes |
| management_gateway | Gateway for the management network | `string` | n/a | yes |
| enable_nat_gateway | Enable NAT gateway for Talos cluster internet access | `bool` | `true` | no |
| nat_gateway_vm_id | VM ID for the NAT gateway | `number` | `200` | no |
| nat_gateway_management_ip | Management IP for the NAT gateway (WAN interface) | `string` | n/a | yes |
| nat_gateway_cluster_ip | Cluster network IP for the NAT gateway (LAN interface) | `string` | n/a | yes |
| nat_gateway_password | Root password for OpenWrt NAT gateway | `string` | `"ChangeMe123!"` | no |
| openwrt_version | OpenWrt version to install | `string` | `"23.05.5"` | no |
| iso_pool | Storage pool for ISO images | `string` | `"storage-isos"` | no |
| talos_control_plane_ips | List of control plane IP addresses for load balancing | `list(string)` | `[]` | no |
| enable_firewall | Enable firewall rules for Talos cluster network | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| bridge_name | Name of the created bridge |
| bridge_ipv4_address | IPv4 address of the bridge |
| nat_gateway_vm_id | NAT gateway VM ID |
| nat_gateway_management_ip | NAT gateway management IP (WAN) |
| nat_gateway_cluster_ip | NAT gateway cluster IP (LAN) |
| talos_network_cidr | Talos network CIDR |
| talos_network_gateway | Talos network gateway |

## 🌐 OpenWrt NAT Gateway Features

This module automatically deploys a fully configured OpenWrt router with **zero manual intervention**:

### 📋 Quick Start

Simply enable the NAT gateway in your configuration:

```hcl
module "talos_network" {
  source = "./modules/talos-network"
  
  # ... other configuration ...
  
  enable_nat_gateway = true
  nat_gateway_cluster_ip = "10.10.0.1"
  nat_gateway_management_ip = "192.168.0.200"
  nat_gateway_password = "my-secure-password"
}
```

That's it! Terraform will handle everything automatically.

### ✨ Automated Installation Process
1. **📥 Downloads** OpenWrt x86-64 image from official sources
2. **🚀 Creates** VM with UEFI boot and dual network interfaces
3. **⏳ Waits** for OpenWrt to boot (60 seconds)
4. **🔧 Configures** via SSH using UCI commands:
   - WAN interface (eth0) with static IP on management network
   - LAN interface (eth1) with static IP on cluster network
   - NAT/Masquerading enabled for internet access
   - Firewall rules for LAN→WAN forwarding
   - Root password setup
   - Hostname configuration

### 🌟 Features
- **Fully Automated**: No manual configuration needed
- **Lightweight**: Only 512MB RAM and 1GB disk
- **Dual Interface**: WAN (management) + LAN (cluster)
- **NAT/Masquerading**: Full internet access for cluster
- **Firewall**: OpenWrt's robust firewall
- **Web UI**: Accessible at `http://<lan_ip>` after deployment
- **SSH Access**: Via both WAN and LAN interfaces

### 🔧 Technical Details
- **OS**: OpenWrt 23.05.5 (configurable)
- **Boot**: UEFI (ovmf)
- **Interfaces**: virtio network devices
- **Configuration**: UCI (Unified Configuration Interface)
- **Management**: SSH + LuCI web interface

### 🌐 Accessing OpenWrt

After deployment (takes ~2-3 minutes):

- **Web UI (LuCI)**: `http://<nat_gateway_cluster_ip>`
  - Login: `root`
  - Password: `<nat_gateway_password>`
  
- **SSH Access**:
  ```bash
  ssh root@<nat_gateway_cluster_ip>
  # or via WAN
  ssh root@<nat_gateway_management_ip>
  ```

- **Configuration Commands** (UCI):
  ```bash
  # View network config
  uci show network
  
  # View firewall config
  uci show firewall
  
  # Apply changes
  uci commit && /etc/init.d/network reload
  ```

## Firewall Rules

When enabled, the following firewall rules are created:

- **Talos API access** (port 50000)
- **Kubernetes API access** (port 6443)
- **etcd access** (ports 2379-2380)
- **Node-to-node communication** (TCP and UDP)
- **NAT gateway access** from management network

## Integration

This module is designed to work with:
- **talos-cluster module** - For complete cluster deployment
- **talos-vm module** - For individual VM creation
- **openwrt-router module** - For NAT gateway functionality

## Notes

- The bridge is created with autostart enabled
- OpenWrt VM uses SSH-based configuration
- Firewall rules are applied at the Proxmox node level
- The module supports both IPv4 and future IPv6 configurations
- NAT gateway configuration is optimized for Talos and Kubernetes
- SSH tunnels are configured for remote access


