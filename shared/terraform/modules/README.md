# Talos Cluster Terraform Modules

This directory contains Terraform modules for deploying Talos Kubernetes clusters on Proxmox. NAT and pod isolation are handled natively by the Proxmox host via iptables.

## Module Structure

```
modules/
├── talos-vm/           # Individual Talos VM module
│   ├── main.tf         # VM creation and Talos configuration
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
├── talos-cluster/      # Complete cluster deployment module
│   ├── templates/      # Talos configuration templates
│   ├── main.tf         # Cluster orchestration
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
└── talos-network/      # Network infrastructure module
    ├── main.tf         # Firewall rules
    ├── variables.tf    # Module variables
    ├── outputs.tf      # Module outputs
    └── README.md       # Module documentation
```

## Quick Start

### 1. Deploy Complete Cluster

```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"

  # Basic configuration
  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"

  # Talos
  talos_version       = "1.11.1"
  talos_image_file_id = "storage-isos:import/talos.qcow2"
  iso_pool            = "storage-isos"

  # Node configuration
  control_plane_count  = 1
  control_plane_ips    = ["10.10.0.10"]
  control_plane_vm_ids = [101]

  worker_count  = 2
  worker_ips    = ["10.10.0.20", "10.10.0.21"]
  worker_vm_ids = [201, 202]

  # Network
  bridge_name             = "vmbr1"
  talos_network_cidr      = "10.10.0.0/24"
  talos_network_gateway   = "10.10.0.1"
  management_network_cidr = "192.168.56.0/24"
  management_gateway      = "192.168.56.1"

  # Firewall
  enable_firewall = true

  # Tunnels
  control_plane_tunnel_ports = [5802]
  worker_tunnel_ports        = [5803, 5804]
}
```

### 2. Access the Cluster

```bash
# Get kubeconfig
tofu output -raw kubeconfig > kubeconfig.yaml

# Get talosconfig
tofu output -raw talosconfig > talosconfig.yaml

# Use kubectl
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

## Module Overview

### talos-vm

Creates individual Talos VMs from disk images.

- VM creation from Talos qcow2 image
- Talos configuration generation and application
- Static IP networking
- Configurable resources

### talos-cluster

Orchestrates complete cluster deployment.

- Control plane and worker node management
- Network firewall rules via talos-network submodule
- Cluster bootstrapping and kubeconfig generation
- SSH tunnel configuration for remote access

### talos-network

Manages Proxmox firewall rules for cluster security.

- Talos API restricted to management network
- Kubernetes API from management and cluster networks
- etcd restricted to cluster-internal
- Node-to-node communication rules

## Network Architecture

NAT masquerade and pod isolation are handled at the Proxmox host level via iptables rules configured by `03a-preflight.ansible.yml`:

- **NAT**: `iptables -t nat POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE`
- **Pod isolation**: FORWARD chain rules block pod subnet (10.244.0.0/16) from management network, Talos API, and direct K8s API

The Proxmox bridge IP (10.10.0.1 on vmbr1) serves as the default gateway for all Talos nodes.

## Prerequisites

- **OpenTofu** >= 1.6 (or Terraform >= 1.0)
- **Proxmox** with API access and bpg/proxmox provider ~> 0.63
- **Talos** >= 1.9.0
- **Talos qcow2 image** downloaded by `02a-prepare-templates.ansible.yml`
- **vmbr1 bridge** created by `03a-preflight.ansible.yml`

## Troubleshooting

### Common Issues

1. **Template not found** — Ensure Talos qcow2 exists in storage
2. **IP conflicts** — Verify IP addresses are not in use
3. **VM ID conflicts** — Ensure VM IDs are unique
4. **Network issues** — Check vmbr1 bridge and iptables rules

### Debug Commands

```bash
# Check cluster status
talosctl get nodes

# Check cluster health
kubectl get nodes -o wide

# Verify iptables masquerade on Proxmox
iptables -t nat -L POSTROUTING -v

# Check Proxmox resources
pvesh get /cluster/resources
```
