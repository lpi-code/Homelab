# Talos Cluster Terraform Modules

This directory contains Terraform modules for deploying Talos Kubernetes clusters on Proxmox using Packer-built templates.

## Module Structure

```
modules/
├── talos-vm/           # Individual Talos VM module
│   ├── packer/         # Packer templates for building Talos images
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
│   ├── templates/      # Cloud-init templates
│   ├── main.tf         # Bridge, firewall, and load balancer
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
├── talos-loadbalancer/ # Dedicated load balancer module
│   ├── templates/      # Cloud-init templates
│   ├── main.tf         # Load balancer VM creation
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
├── talos-image-factory/ # Custom Talos image creation module
│   ├── main.tf         # Image factory resources
│   ├── variables.tf    # Module variables
│   ├── outputs.tf      # Module outputs
│   └── README.md       # Module documentation
└── talos-vm-template/  # VM template creation module
    ├── main.tf         # Template creation with image factory
    ├── variables.tf    # Module variables
    ├── outputs.tf      # Module outputs
    └── README.md       # Module documentation
```

## Quick Start

### 1. Build Talos Template with Packer

```bash
cd modules/talos-vm/packer
export PKR_VAR_proxmox_token="your-proxmox-api-token"
packer init .
packer build .
```

### 2. Deploy Complete Cluster

```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"

  # Basic configuration
  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 9999  # Packer-built template

  # Node configuration
  control_plane_count = 3
  worker_count = 3

  # Control plane configuration
  control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids = [100, 101, 102]

  # Worker configuration
  worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22"]
  worker_vm_ids = [120, 121, 122]

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # Load balancer configuration
  enable_load_balancer = true
  load_balancer_vm_id = 200
  load_balancer_management_ip = "192.168.0.200"
  load_balancer_cluster_ip = "10.10.0.200"
  ssh_public_keys = ["ssh-rsa AAAAB3NzaC1yc2E... user@host"]
}
```

### 3. Access the Cluster

```bash
# Get kubeconfig
terraform output -raw kubeconfig > kubeconfig

# Get talosconfig
terraform output -raw talosconfig > talosconfig

# Use kubectl
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Use talosctl
export TALOSCONFIG=./talosconfig
talosctl get nodes
```

## Module Overview

### talos-vm Module

Creates individual Talos VMs from Packer-built templates.

**Features:**
- VM creation from templates
- Talos configuration generation
- Static IP or DHCP networking
- Configurable resources

**Usage:**
```hcl
module "talos_vm" {
  source = "./modules/talos-vm"
  
  vm_name = "talos-cp-1"
  vm_id = 100
  template_vm_id = 9999
  
  # ... other configuration
}
```

### talos-cluster Module

Orchestrates complete cluster deployment.

**Features:**
- Multiple control plane and worker nodes
- Network infrastructure
- Optional load balancer
- Cluster bootstrapping
- Kubeconfig generation

**Usage:**
```hcl
module "talos_cluster" {
  source = "./modules/talos-cluster"
  
  cluster_name = "dev-cluster"
  # ... other configuration
}
```

### network Module

Creates network infrastructure for the cluster.

**Features:**
- Dedicated network bridges
- Firewall rules
- Optional load balancer VM
- Network isolation

**Usage:**
```hcl
module "network" {
  source = "./modules/talos-network"
  
  cluster_name = "dev-cluster"
  # ... other configuration
}
```

### talos-loadbalancer Module

Creates dedicated load balancer VMs.

**Features:**
- HAProxy for load balancing
- Keepalived for high availability
- Health checks
- Statistics interface

**Usage:**
```hcl
module "load_balancer" {
  source = "./modules/talos-loadbalancer"
  
  cluster_name = "dev-cluster"
  # ... other configuration
}
```

### talos-image-factory Module

Creates custom Talos Linux images using the Talos Image Factory API.

**Features:**
- Custom system extensions
- Reproducible builds
- Reduced bootstrap time
- Hardware optimization
- Proxmox integration

**Usage:**
```hcl
module "talos_image_factory" {
  source = "./modules/talos-image-factory"
  
  talos_version = "1.9.5"
  proxmox_node  = "pve02"
  iso_pool      = "storage-isos"
  
  # Custom extensions
  system_extensions = [
    "siderolabs/intel-ucode",
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools"
  ]
  
  # ... other configuration
}
```

### talos-vm-template Module

Creates Talos VM templates using custom images from talos-image-factory.

**Features:**
- Custom Talos images with system extensions
- Shut down VM template ready for cloning
- Hardware configuration options
- Beautiful emoji descriptions
- QEMU agent pre-configured

**Usage:**
```hcl
module "talos_vm_template" {
  source = "./modules/talos-vm-template"
  
  talos_version = "1.9.5"
  proxmox_node  = "pve02"
  iso_pool      = "storage-isos"
  storage_pool  = "local-zfs"
  
  template_name   = "talos-template-v1.9.5"
  template_vm_id  = 9999
  
  # Custom extensions
  system_extensions = [
    "siderolabs/intel-ucode",
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools"
  ]
  
  # ... other configuration
}
```

## Prerequisites

### Required Software

- **Terraform** >= 1.0
- **Packer** >= 1.8.0
- **Proxmox** with API access
- **Talos** >= 0.3.0

### Required Permissions

- Proxmox API token with VM creation permissions
- Network bridge creation permissions
- Firewall rule management permissions

### Required Resources

- Proxmox storage pool for VMs
- Proxmox storage pool for ISOs
- Network bridges (vmbr0, vmbr1)
- IP address ranges for management and cluster networks

## Configuration Examples

### Development Cluster

```hcl
module "dev_cluster" {
  source = "./modules/talos-cluster"

  cluster_name = "dev-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 9999

  # Minimal configuration
  control_plane_count = 1
  worker_count = 2

  control_plane_ips = ["10.10.0.10"]
  control_plane_vm_ids = [100]

  worker_ips = ["10.10.0.20", "10.10.0.21"]
  worker_vm_ids = [120, 121]

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # Disable load balancer for dev
  enable_load_balancer = false
}
```

### Production Cluster

```hcl
module "prod_cluster" {
  source = "./modules/talos-cluster"

  cluster_name = "prod-cluster"
  proxmox_node = "pve02"
  storage_pool = "local-zfs"
  template_vm_id = 9999

  # High availability configuration
  control_plane_count = 3
  worker_count = 5

  control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
  control_plane_vm_ids = [100, 101, 102]
  control_plane_cores = 4
  control_plane_memory = 8192
  control_plane_disk_size = "100G"

  worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22", "10.10.0.23", "10.10.0.24"]
  worker_vm_ids = [120, 121, 122, 123, 124]
  worker_cores = 8
  worker_memory = 16384
  worker_disk_size = "200G"

  # Network configuration
  talos_network_cidr = "10.10.0.0/24"
  talos_network_gateway = "10.10.0.1"
  management_network_cidr = "192.168.0.0/24"
  management_gateway = "192.168.0.1"

  # Load balancer configuration
  enable_load_balancer = true
  load_balancer_vm_id = 200
  load_balancer_management_ip = "192.168.0.200"
  load_balancer_cluster_ip = "10.10.0.200"
  ssh_public_keys = [
    "ssh-rsa AAAAB3NzaC1yc2E... admin@host1",
    "ssh-rsa AAAAB3NzaC1yc2E... admin@host2"
  ]
}
```

## Best Practices

### Security

- Use strong passwords for HAProxy statistics
- Restrict SSH access to specific IP ranges
- Enable firewall rules for network isolation
- Use static IP addresses for production deployments

### Performance

- Allocate sufficient resources for control plane nodes
- Use SSD storage for better performance
- Enable QEMU guest agent for better integration
- Monitor cluster health and performance

### Reliability

- Use odd number of control plane nodes (3 or 5)
- Enable load balancer for high availability
- Use dedicated network bridges for isolation
- Implement backup and disaster recovery procedures

### Monitoring

- Access HAProxy statistics for load balancer monitoring
- Use Talos and Kubernetes monitoring tools
- Monitor cluster health and performance metrics
- Set up alerting for critical issues

## Troubleshooting

### Common Issues

1. **Template not found** - Ensure Packer template exists with correct VM ID
2. **IP conflicts** - Verify IP addresses are not in use
3. **VM ID conflicts** - Ensure VM IDs are unique
4. **Network issues** - Check bridge configuration and firewall rules
5. **Load balancer issues** - Verify HAProxy and Keepalived configuration

### Debug Commands

```bash
# Check cluster status
talosctl get nodes

# Check cluster health
kubectl get nodes -o wide

# Check load balancer status
curl http://<load_balancer_ip>:8404/stats

# Check Proxmox resources
pvesh get /cluster/resources
```

## Contributing

1. Follow Terraform best practices
2. Update documentation for any changes
3. Test modules in development environment
4. Use consistent naming conventions
5. Add appropriate validation rules

## License

This project is licensed under the MIT License - see the LICENSE file for details.


