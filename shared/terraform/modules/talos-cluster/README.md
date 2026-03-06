# Talos Cluster Module

This Terraform module creates a complete Talos Kubernetes cluster on Proxmox, including control plane nodes, worker nodes, network firewall rules, cluster bootstrapping, and kubeconfig generation.

## Features

- Complete cluster deployment with control plane and worker nodes
- Network firewall rules via talos-network submodule
- Automatic Talos configuration generation and application
- Cluster bootstrapping and kubeconfig generation
- Flexible scaling for both control plane and worker nodes
- SSH tunnel support for remote access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Node                             │
│                 (iptables masquerade)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────┐                      │
│  │  Control Plane  │  │   Workers    │                      │
│  │     Nodes       │  │              │                      │
│  │                 │  │              │                      │
│  │ talos-cp-1      │  │ talos-w-1    │                      │
│  │ talos-cp-2      │  │ talos-w-2    │                      │
│  │ talos-cp-3      │  │ talos-w-3    │                      │
│  └─────────────────┘  └──────────────┘                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Dedicated Bridge (vmbr1)                   │ │
│  │          10.10.0.0/24 — GW: 10.10.0.1 (Proxmox)       │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"

  # Basic configuration
  cluster_name  = "dev-cluster"
  proxmox_node  = "pve02"
  storage_pool  = "local-zfs"
  talos_version = "1.11.1"

  # Storage
  talos_image_file_id = "storage-isos:import/talos.qcow2"
  iso_pool            = "storage-isos"

  # Control plane
  control_plane_count        = 3
  control_plane_ips          = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids       = [100, 101, 102]
  control_plane_cores        = 2
  control_plane_memory       = 4096
  control_plane_disk_size    = "50G"
  control_plane_tunnel_ports = [5802, 5803, 5804]

  # Workers
  worker_count        = 3
  worker_ips          = ["10.10.0.20", "10.10.0.21", "10.10.0.22"]
  worker_vm_ids       = [120, 121, 122]
  worker_cores        = 4
  worker_memory       = 8192
  worker_disk_size    = "100G"
  worker_tunnel_ports = [5810, 5811, 5812]

  # Network — Proxmox is the gateway
  bridge_name             = "vmbr1"
  talos_network_cidr      = "10.10.0.0/24"
  talos_network_gateway   = "10.10.0.1"
  management_network_cidr = "192.168.56.0/24"
  management_gateway      = "192.168.56.1"

  # Firewall
  enable_firewall = true
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
| cluster_name | Name of the Talos cluster | `string` | n/a | yes |
| proxmox_node | Proxmox node name | `string` | n/a | yes |
| storage_pool | Storage pool for VMs | `string` | n/a | yes |
| talos_version | Talos Linux version (X.Y.Z) | `string` | n/a | yes |
| kubernetes_version | Kubernetes version | `string` | `"1.33.1"` | no |
| talos_image_file_id | Talos qcow2 file ID in Proxmox storage | `string` | n/a | yes |
| iso_pool | Storage pool for ISO images | `string` | n/a | yes |
| control_plane_count | Number of control plane nodes (1-5) | `number` | n/a | yes |
| control_plane_ips | Control plane IP addresses | `list(string)` | n/a | yes |
| control_plane_vm_ids | Control plane VM IDs | `list(number)` | n/a | yes |
| control_plane_cores | CPU cores per control plane node (1-32) | `number` | n/a | yes |
| control_plane_memory | Memory in MB per control plane node | `number` | n/a | yes |
| control_plane_disk_size | Disk size per control plane node | `string` | n/a | yes |
| control_plane_tunnel_ports | Local ports for control plane SSH tunnels | `list(number)` | n/a | yes |
| worker_count | Number of worker nodes | `number` | n/a | yes |
| worker_ips | Worker IP addresses | `list(string)` | n/a | yes |
| worker_vm_ids | Worker VM IDs | `list(number)` | n/a | yes |
| worker_cores | CPU cores per worker node (1-32) | `number` | n/a | yes |
| worker_memory | Memory in MB per worker node | `number` | n/a | yes |
| worker_disk_size | Disk size per worker node | `string` | n/a | yes |
| worker_tunnel_ports | Local ports for worker SSH tunnels | `list(number)` | n/a | yes |
| bridge_name | Dedicated bridge for Talos cluster | `string` | n/a | yes |
| talos_network_cidr | Cluster network CIDR | `string` | n/a | yes |
| talos_network_gateway | Cluster gateway (Proxmox bridge IP) | `string` | n/a | yes |
| management_network_cidr | Management network CIDR | `string` | n/a | yes |
| management_gateway | Management network gateway | `string` | n/a | yes |
| enable_firewall | Enable Proxmox firewall rules | `bool` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bridge_name | Name of the cluster bridge |
| bridge_ipv4_address | IPv4 address of the bridge |
| cluster_name | Cluster name |
| cluster_endpoint | Kubernetes API endpoint URL |
| talos_network_cidr | Cluster network CIDR |
| talos_network_gateway | Cluster gateway IP |
| control_plane_vm_ids | Control plane VM IDs |
| control_plane_ips | Control plane IP addresses |
| control_plane_names | Control plane VM names |
| worker_vm_ids | Worker VM IDs |
| worker_ips | Worker IP addresses |
| worker_names | Worker VM names |
| kubeconfig | Kubernetes kubeconfig |
| talosconfig | Talos client configuration |
| bootstrap_complete | Whether cluster bootstrapping completed |

## Prerequisites

1. **Talos qcow2 image** — downloaded by `02a-prepare-templates.ansible.yml`
2. **vmbr1 bridge** — created by `03a-preflight.ansible.yml` with masquerade
3. **Proxmox API access** — configured with VM creation permissions
4. **IP planning** — IP ranges and VM IDs planned in advance

## Deployment Process

1. Run `02a-prepare-templates.ansible.yml` to download Talos image
2. Run `03a-preflight.ansible.yml` to create vmbr1 with masquerade and pod isolation
3. Run `03b-deploy-cluster.sh` which calls `tofu apply`
4. Access cluster using generated kubeconfig/talosconfig

## Accessing the Cluster

```bash
tofu output -raw kubeconfig > kubeconfig.yaml
tofu output -raw talosconfig > talosconfig.yaml

export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes

export TALOSCONFIG=./talosconfig.yaml
talosctl get nodes
```

## Scaling

### Adding Worker Nodes

1. Update `worker_count`
2. Add IPs to `worker_ips`
3. Add VM IDs to `worker_vm_ids`
4. Add tunnel ports to `worker_tunnel_ports`
5. Run `tofu apply`

### Adding Control Plane Nodes

1. Update `control_plane_count`
2. Add IPs to `control_plane_ips`
3. Add VM IDs to `control_plane_vm_ids`
4. Add tunnel ports to `control_plane_tunnel_ports`
5. Run `tofu apply`

## Troubleshooting

1. **Talos image not found** — Run `02a-prepare-templates.ansible.yml`
2. **vmbr1 missing** — Run `03a-preflight.ansible.yml`
3. **No internet from nodes** — Check iptables masquerade: `iptables -t nat -L POSTROUTING`
4. **IP conflicts** — Verify IP addresses are not in use
5. **Network issues** — Check bridge config and firewall rules

```bash
talosctl get nodes
kubectl get nodes -o wide
iptables -t nat -L POSTROUTING -v
pvesh get /cluster/resources
```

## Integration

- **talos-network module** — firewall rules
- **talos-vm module** — individual VM creation

## Notes

- Proxmox acts as the cluster gateway via iptables masquerade on vmbr1
- Pod isolation (10.244.0.0/16 blocked from management, Talos API, K8s API) is configured on the Proxmox host
- The cluster is automatically bootstrapped after all nodes are created
- All VMs use static IP configuration
- SSH tunnels are used for remote access through the Proxmox host
