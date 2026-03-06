# Talos Network Module

This Terraform module creates network infrastructure for a Talos Kubernetes cluster on Proxmox, including firewall rules for cluster security and pod isolation.

NAT masquerade and pod isolation iptables rules are configured on the Proxmox host by `03a-preflight.ansible.yml` before Terraform runs. This module manages only the Proxmox firewall rules.

## Features

- Configurable Proxmox firewall rules for cluster security
- Talos API access restricted to management network
- Kubernetes API access from management and cluster networks
- etcd access restricted to cluster-internal traffic
- Node-to-node TCP/UDP communication

## Usage

```hcl
module "talos_network" {
  source = "./modules/talos-network"

  # Basic configuration
  proxmox_node = "pve02"
  cluster_name = "dev-cluster"
  storage_pool = "local-zfs"

  # Bridge configuration
  bridge_name        = "vmbr1"
  bridge_ipv4_address = "10.10.0.1/24"

  # Network configuration
  talos_network_cidr      = "10.10.0.0/24"
  talos_network_gateway   = "10.10.0.1"
  management_network_cidr = "192.168.56.0/24"
  management_gateway      = "192.168.56.1"

  # Firewall configuration
  enable_firewall = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
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
| talos_network_gateway | Gateway for the Talos cluster network (Proxmox bridge IP) | `string` | n/a | yes |
| management_network_cidr | CIDR for the management network | `string` | n/a | yes |
| management_gateway | Gateway for the management network | `string` | n/a | yes |
| enable_firewall | Enable firewall rules for Talos cluster network | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| bridge_name | Name of the bridge (created by 03a-preflight.ansible.yml) |
| bridge_ipv4_address | IPv4 address of the bridge |
| talos_network_cidr | Talos network CIDR |
| talos_network_gateway | Talos network gateway |

## Firewall Rules

When enabled, the following Proxmox firewall rules are created:

- **Talos API** (port 50000) — from management network only
- **Kubernetes API** (port 6443) — from management and cluster networks
- **etcd** (ports 2379-2380) — cluster-internal only
- **Node-to-node** (TCP and UDP) — cluster-internal

## Network Architecture

```
                    Proxmox Host
  ┌──────────────────────────────────────────┐
  │  vmbr0 (management)  │  vmbr1 (cluster)  │
  │  192.168.56.0/24      │  10.10.0.0/24     │
  │                       │  iptables masq    │
  │                       │  pod isolation    │
  └───────────────────────┴───────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         talos-cp-1      talos-cp-2      talos-w-1
         10.10.0.10      10.10.0.11      10.10.0.20
```

NAT masquerade on vmbr1 provides internet access. Pod isolation iptables rules on the Proxmox host block pod traffic (10.244.0.0/16) from reaching the management network, Talos API, and direct Kubernetes API.

## Integration

This module is designed to work with:
- **talos-cluster module** — orchestrates complete cluster deployment
- **talos-vm module** — creates individual Talos VMs

## Notes

- Bridge vmbr1 is created by `03a-preflight.ansible.yml`, not by Terraform
- Proxmox acts as the cluster gateway (10.10.0.1) with iptables masquerade
- Firewall rules are applied at the Proxmox node level
