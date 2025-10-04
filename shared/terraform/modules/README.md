# Talos Cluster Terraform Modules

This directory contains Terraform modules for deploying Talos Kubernetes clusters on Proxmox with OpenWrt NAT gateway support.

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
├── talos-network/      # Network infrastructure module
│   ├── templates/      # OpenWrt configuration templates
│   ├── main.tf         # Bridge, firewall, and NAT gateway
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
└── openwrt-router/     # OpenWrt router module
    ├── main.tf         # OpenWrt VM creation and configuration
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
  template_vm_id = 100  # Talos template VM ID

  # Node configuration
  control_plane_count = 3
  worker_count = 3

  # Control plane configuration
  control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids = [101, 102, 103]

  # Worker configuration
  worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22"]
  worker_vm_ids = [201, 202, 203]

  # Network configuration
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
}
```

### 2. Access the Cluster

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

## Module Overview

### talos-vm Module

Creates individual Talos VMs from existing templates.

**Features:**
- VM creation from templates
- Talos configuration generation
- Static IP networking
- Configurable resources
- Automatic Talos configuration application

**Usage:**
```hcl
module "talos_vm" {
  source = "./modules/talos-vm"
  
  vm_name = "talos-cp-1"
  vm_id = 100
  template_vm_id = 100
  
  # ... other configuration
}
```

### talos-cluster Module

Orchestrates complete cluster deployment.

**Features:**
- Multiple control plane and worker nodes
- Network infrastructure with OpenWrt NAT gateway
- Cluster bootstrapping
- Kubeconfig generation
- Automatic Talos configuration

**Usage:**
```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"
  
  cluster_name = "dev-cluster"
  # ... other configuration
}
```

### talos-network Module

Creates network infrastructure for the cluster.

**Features:**
- Dedicated network bridges
- OpenWrt NAT gateway with automatic configuration
- Firewall rules
- Network isolation
- SSH-based OpenWrt configuration

**Usage:**
```hcl
module "network" {
  source = "./modules/talos-network"
  
  cluster_name = "dev-cluster"
  # ... other configuration
}
```

### openwrt-router Module

Creates OpenWrt router VMs for NAT gateway functionality.

**Features:**
- OpenWrt VM creation
- Automatic network configuration via SSH
- NAT masquerading
- Firewall rules
- Web UI access

**Usage:**
```hcl
module "openwrt_router" {
  source = "./modules/openwrt-router"
  
  vm_name = "openwrt-nat-gateway"
  vm_id = 200
  # ... other configuration
}
```

## Prerequisites

### Required Software

- **OpenTofu** >= 1.6 (or Terraform >= 1.0)
- **Proxmox** with API access
- **Talos** >= 1.9.0
- **OpenWrt** image for NAT gateway

### Required Permissions

- Proxmox API access with VM creation permissions
- Network bridge creation permissions
- Firewall rule management permissions

### Required Resources

- Proxmox storage pool for VMs
- Proxmox storage pool for ISOs
- Network bridges (vmbr0, vmbr1)
- IP address ranges for management and cluster networks
- Talos template VM (ID 100)

## Configuration Examples

### Development Cluster

```hcl
module "dev_cluster" {
  source = "./modules/talos-cluster"

  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 100

  # Minimal configuration
  control_plane_count = 1
  worker_count = 2

  control_plane_ips = ["10.10.0.10"]
  control_plane_vm_ids = [101]

  worker_ips = ["10.10.0.20", "10.10.0.21"]
  worker_vm_ids = [201, 202]

  # Network configuration
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
}
```

### Production Cluster

```hcl
module "prod_cluster" {
  source = "./modules/talos-cluster"

  cluster_name = "prod-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 100

  # High availability configuration
  control_plane_count = 3
  worker_count = 5

  control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids = [101, 102, 103]
  control_plane_cores = 4
  control_plane_memory = 8192
  control_plane_disk_size = "100G"

  worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22", "10.10.0.23", "10.10.0.24"]
  worker_vm_ids = [201, 202, 203, 204, 205]
  worker_cores = 8
  worker_memory = 16384
  worker_disk_size = "200G"

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # NAT gateway configuration
  enable_nat_gateway = true
  nat_gateway_vm_id = 200
  nat_gateway_management_ip = "192.168.0.200"
  nat_gateway_cluster_ip = "10.10.0.200"
  nat_gateway_password = "SecurePassword123!"
  openwrt_version = "23.05.5"
  iso_pool = "storage-isos"
}
```

## Best Practices

### Security

- Use strong passwords for OpenWrt NAT gateway
- Restrict SSH access to specific IP ranges
- Enable firewall rules for network isolation
- Use static IP addresses for production deployments
- Encrypt secrets using SOPS

### Performance

- Allocate sufficient resources for control plane nodes
- Use SSD storage for better performance
- Enable QEMU guest agent for better integration
- Monitor cluster health and performance

### Reliability

- Use odd number of control plane nodes (3 or 5)
- Enable NAT gateway for internet access
- Use dedicated network bridges for isolation
- Implement backup and disaster recovery procedures

### Monitoring

- Access OpenWrt web interface for network monitoring
- Use Talos and Kubernetes monitoring tools
- Monitor cluster health and performance metrics
- Set up alerting for critical issues

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

# Check Proxmox resources
pvesh get /cluster/resources
```

## Contributing

1. Follow OpenTofu/Terraform best practices
2. Update documentation for any changes
3. Test modules in development environment
4. Use consistent naming conventions
5. Add appropriate validation rules

## License

This project is licensed under the MIT License - see the LICENSE file for details.


