# Talos Cluster Module

This Terraform module creates a complete Talos Kubernetes cluster on Proxmox, including control plane nodes, worker nodes, network infrastructure, and OpenWrt NAT gateway.

## Features

- **Complete cluster deployment** with control plane and worker nodes
- **Network infrastructure** with dedicated bridges and firewall rules
- **OpenWrt NAT gateway** with automatic configuration
- **Automatic Talos configuration** generation and application
- **Cluster bootstrapping** and kubeconfig generation
- **Flexible scaling** for both control plane and worker nodes
- **SSH tunnel support** for remote access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Node                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ OpenWrt NAT     │  │  Control Plane  │  │   Workers    │ │
│  │   Gateway       │  │     Nodes       │  │              │ │
│  │                 │  │                 │  │              │ │
│  │ OpenWrt Router  │  │ talos-cp-1      │  │ talos-w-1    │ │
│  │ NAT Masquerading│  │ talos-cp-2      │  │ talos-w-2    │ │
│  │                 │  │ talos-cp-3      │  │ talos-w-3    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Dedicated Bridge (vmbr1)                  │ │
│  │                10.10.0.0/24                            │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"

  # Basic configuration
  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 9999  # Packer-built template

  # Talos configuration
  talos_version = "1.9.5"

  # Node configuration
  control_plane_count = 3
  worker_count = 3

  # Control plane configuration
  control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids = [100, 101, 102]
  control_plane_cores = 2
  control_plane_memory = 4096
  control_plane_disk_size = "50G"

  # Worker configuration
  worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22"]
  worker_vm_ids = [120, 121, 122]
  worker_cores = 4
  worker_memory = 8192
  worker_disk_size = "100G"

  # Network configuration
  bridge_name = "vmbr1"
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # NAT gateway configuration
  enable_nat_gateway = true
  nat_gateway_vm_id = 200
  nat_gateway_management_ip = "192.168.0.200"
  nat_gateway_cluster_ip = "10.10.0.200"
  nat_gateway_password = "ChangeMe123!"
  openwrt_version = "23.05.5"
  iso_pool = "storage-isos"

  # Firewall configuration
  enable_firewall = true
}
```

### Minimal Example (No NAT Gateway)

```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"

  # Basic configuration
  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 100

  # Node configuration
  control_plane_count = 1
  worker_count = 2

  # Control plane configuration
  control_plane_ips = ["10.10.0.10"]
  control_plane_vm_ids = [101]

  # Worker configuration
  worker_ips = ["10.10.0.20", "10.10.0.21"]
  worker_vm_ids = [201, 202]

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # Disable NAT gateway
  enable_nat_gateway = false
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
| cluster_name | Name of the Talos cluster | `string` | n/a | yes |
| proxmox_node | Proxmox node name | `string` | n/a | yes |
| storage_pool | Storage pool for VMs | `string` | n/a | yes |
| template_vm_id | Template VM ID to clone from | `number` | n/a | yes |
| talos_version | Talos Linux version | `string` | `"1.9.5"` | no |
| control_plane_count | Number of control plane nodes | `number` | `3` | no |
| worker_count | Number of worker nodes | `number` | `3` | no |
| control_plane_ips | List of control plane IP addresses | `list(string)` | n/a | yes |
| control_plane_vm_ids | List of control plane VM IDs | `list(number)` | n/a | yes |
| control_plane_cores | Number of CPU cores for control plane nodes | `number` | `2` | no |
| control_plane_memory | Memory in MB for control plane nodes | `number` | `4096` | no |
| control_plane_disk_size | Disk size for control plane nodes | `string` | `"50G"` | no |
| worker_ips | List of worker IP addresses | `list(string)` | n/a | yes |
| worker_vm_ids | List of worker VM IDs | `list(number)` | n/a | yes |
| worker_cores | Number of CPU cores for worker nodes | `number` | `4` | no |
| worker_memory | Memory in MB for worker nodes | `number` | `8192` | no |
| worker_disk_size | Disk size for worker nodes | `string` | `"100G"` | no |
| bridge_name | Name of the dedicated bridge for Talos cluster | `string` | `"vmbr1"` | no |
| talos_network_cidr | CIDR for the Talos cluster network | `string` | `"10.10.0.0/24"` | no |
| talos_network_gateway | Gateway for the Talos cluster network | `string` | `"10.10.0.1"` | no |
| management_network_cidr | CIDR for the management network | `string` | `"192.168.0.0/24"` | no |
| management_gateway | Gateway for the management network | `string` | `"192.168.0.1"` | no |
| enable_nat_gateway | Enable NAT gateway for Talos cluster internet access | `bool` | `true` | no |
| nat_gateway_vm_id | VM ID for the NAT gateway | `number` | `200` | no |
| nat_gateway_management_ip | Management IP for the NAT gateway (WAN interface) | `string` | `"192.168.0.200"` | no |
| nat_gateway_cluster_ip | Cluster network IP for the NAT gateway (LAN interface) | `string` | `"10.10.0.200"` | no |
| nat_gateway_password | Root password for OpenWrt NAT gateway | `string` | `"ChangeMe123!"` | no |
| openwrt_version | OpenWrt version to install | `string` | `"23.05.5"` | no |
| iso_pool | Storage pool for ISO images | `string` | `"storage-isos"` | no |
| ssh_public_keys | List of SSH public keys for access | `list(string)` | `[]` | no |
| enable_firewall | Enable firewall rules for Talos cluster network | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| bridge_name | Name of the created bridge |
| bridge_ipv4_address | IPv4 address of the bridge |
| nat_gateway_vm_id | NAT gateway VM ID |
| nat_gateway_management_ip | NAT gateway management IP (WAN) |
| nat_gateway_cluster_ip | NAT gateway cluster IP (LAN) |
| cluster_name | Name of the Talos cluster |
| cluster_endpoint | Cluster endpoint URL |
| talos_network_cidr | Talos network CIDR |
| talos_network_gateway | Talos network gateway |
| control_plane_vm_ids | Control plane VM IDs |
| control_plane_ips | Control plane IP addresses |
| control_plane_names | Control plane VM names |
| worker_vm_ids | Worker VM IDs |
| worker_ips | Worker IP addresses |
| worker_names | Worker VM names |
| machine_secrets | Talos machine secrets |
| client_configuration | Talos client configuration |
| kubeconfig | Kubernetes kubeconfig |
| talosconfig | Talos talosconfig |
| bootstrap_complete | Whether the cluster has been bootstrapped |

## Prerequisites

1. **Talos template VM** - Pre-created Talos template VM (ID 100)
2. **Proxmox API access** - Configured with appropriate permissions
3. **Network planning** - IP ranges and VM IDs planned in advance
4. **OpenWrt image** - Available in the specified ISO pool
5. **SSH keys** - For access (if needed)

## Deployment Process

1. **Create Talos template** VM (ID 100)
2. **Plan IP addresses** and VM IDs
3. **Deploy cluster** using this module
4. **Access cluster** using generated kubeconfig

## Accessing the Cluster

After deployment, you can access the cluster using:

```bash
# Get kubeconfig
tofu output -raw kubeconfig > kubeconfig.yaml

# Get talosconfig
tofu output -raw talosconfig > talos_client_configuration.yaml

# Use kubectl
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes

# Use talosctl
export TALOSCONFIG=./talos_client_configuration.yaml
talosctl get nodes
```

## Scaling

### Adding Worker Nodes

1. Update the `worker_count` variable
2. Add corresponding IPs to `worker_ips`
3. Add corresponding VM IDs to `worker_vm_ids`
4. Run `tofu apply`

### Adding Control Plane Nodes

1. Update the `control_plane_count` variable
2. Add corresponding IPs to `control_plane_ips`
3. Add corresponding VM IDs to `control_plane_vm_ids`
4. Run `tofu apply`

## Troubleshooting

### Common Issues

1. **Template not found** - Ensure Talos template exists with correct VM ID
2. **IP conflicts** - Verify IP addresses are not in use
3. **VM ID conflicts** - Ensure VM IDs are unique
4. **Network issues** - Check bridge configuration and firewall rules
5. **OpenWrt configuration issues** - Verify SSH access and network configuration

### Debug Commands

```bash
# Check cluster status
talosctl get nodes

# Check cluster health
kubectl get nodes -o wide

# Check OpenWrt NAT gateway
ssh root@<nat_gateway_ip>
uci show network
uci show firewall
```

## Integration

This module integrates with:
- **Talos VM module** - For individual VM creation
- **Network module** - For network infrastructure
- **OpenWrt router module** - For NAT gateway functionality

## Notes

- The cluster is automatically bootstrapped after all nodes are created
- OpenWrt NAT gateway provides internet access for cluster nodes
- Firewall rules are automatically configured for cluster security
- All VMs use static IP configuration for reliability
- The module supports both IPv4 and future IPv6 configurations
- SSH tunnels are configured for remote access to cluster nodes


