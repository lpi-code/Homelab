# 🚀 Development Environment - Talos Kubernetes Cluster

This directory contains the configuration for deploying a Talos Kubernetes cluster in the development environment using Ansible and OpenTofu.

## 📁 Directory Structure

```
environments/dev/
├── ansible/                    # Ansible configuration
│   ├── group_vars/
│   │   ├── all/               # Global variables
│   │   │   └── secrets.sops.yaml # Encrypted secrets
│   │   ├── dev/               # Dev environment variables
│   │   │   └── main.yaml      # Dev-specific configuration
│   │   ├── dev_pve/           # Proxmox VE group variables
│   │   │   └── main.yaml      # Proxmox configuration
│   │   └── dev_talos/         # Talos cluster variables
│   │       └── main.yaml      # Talos cluster configuration
│   ├── host_vars/
│   │   └── pve02/             # Host-specific variables
│   │       ├── 00-general.yaml
│   │       ├── 01-storage.yaml
│   │       ├── 02-network.yaml
│   │       ├── 03-proxmox.yaml
│   │       ├── 04-talos.yaml
│   │       └── 99-secrets.sops.yaml
│   └── inventory/
│       └── hosts.toml         # Inventory file
├── terraform/                  # OpenTofu configuration
│   ├── main.tf                # Main Talos cluster configuration
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf             # Output definitions
│   ├── data-sources.tf        # Ansible data integration
│   ├── versions.tf            # Provider versions
│   ├── terraform.tfvars.example # Example variables
│   └── terraform.tfstate      # State file
├── kubernetes/                 # Kubernetes configurations
│   ├── apps/                  # Application manifests
│   └── clusters/              # Cluster-specific configs
└── README.md                  # This file
```

## 🎯 Quick Start

### Prerequisites

1. **Proxmox VE**: A running Proxmox node (pve02)
2. **Ansible**: Installed on your local machine
3. **OpenTofu**: Installed on your local machine
4. **SSH Access**: Configured to the Proxmox node
5. **SOPS**: For secrets management

### Deploy the Talos Cluster

1. **Configure Variables**:
   ```bash
   # Copy example variables
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   
   # Edit variables as needed
   vim terraform/terraform.tfvars
   ```

2. **Deploy with OpenTofu**:
   ```bash
   cd environments/dev/terraform
   tofu init
   tofu plan
   tofu apply
   ```

3. **Access the Cluster**:
   ```bash
   # Get kubeconfig
   export KUBECONFIG=./kubeconfig.yaml
   kubectl get nodes
   
   # Get talosconfig
   export TALOSCONFIG=./talos_client_configuration.yaml
   talosctl get nodes
   ```

## 🔧 Configuration

### Cluster Configuration

The main cluster configuration is in `ansible/group_vars/dev_talos/main.yaml`:

- **Cluster Name**: `dev-talos`
- **Control Planes**: 3 nodes (10.10.0.10-12)
- **Workers**: 3 nodes (10.10.0.20-22)
- **NAT Gateway**: 192.168.0.200 (WAN) / 10.10.0.200 (LAN)
- **Network**: 10.10.0.0/24
- **Talos Version**: 1.9.5

### Host Configuration

Host-specific settings are in `ansible/host_vars/pve02/`:

- **Proxmox Node**: pve02
- **Storage Pool**: local-lvm
- **Template VM ID**: 100
- **Tunnel Port**: 5801

### Terraform Variables

Key variables in `terraform/terraform.tfvars`:

- **Proxmox API**: https://192.168.0.149:8006/
- **Storage Pool**: storage-vms
- **ISO Pool**: storage-isos
- **OpenWrt Version**: 23.05.5

## 🌐 Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Management Network                       │
│                    192.168.0.0/24                          │
│                                                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │   Your PC   │    │           pve02                     │ │
│  │             │    │      (Proxmox Node)                 │ │
│  │ 192.168.0.x │    │        192.168.0.149                │ │
│  └─────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ vmbr0
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Talos Cluster Network                    │
│                    10.10.0.0/24                            │
│                                                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │ OpenWrt NAT │    │        Talos Cluster                │ │
│  │   Gateway   │    │                                     │ │
│  │ 10.10.0.200 │    │  Control Planes: .10, .11, .12     │ │
│  │             │    │  Workers: .20, .21, .22            │ │
│  │ 192.168.0.200│   │                                     │ │
│  └─────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Network Components

- **Management Network (192.168.0.0/24)**: Proxmox management and OpenWrt WAN interface
- **Cluster Network (10.10.0.0/24)**: Talos cluster internal communication
- **OpenWrt NAT Gateway**: Provides internet access for cluster nodes
- **Bridge vmbr1**: Dedicated bridge for cluster network isolation

## 📊 Cluster Information

After deployment, you can access:

- **Kubernetes API**: `https://10.10.0.10:6443`
- **OpenWrt Web UI**: `http://10.10.0.200` (LuCI interface)
- **OpenWrt SSH**: `ssh root@10.10.0.200`
- **Cluster Network**: `10.10.0.0/24`

## 🔑 Access the Cluster

1. **Get Kubeconfig**:
   ```bash
   cd environments/dev/terraform
   export KUBECONFIG=./kubeconfig.yaml
   kubectl get nodes
   ```

2. **Get Talos Configuration**:
   ```bash
   export TALOSCONFIG=./talos_client_configuration.yaml
   talosctl get nodes
   ```

3. **Access OpenWrt NAT Gateway**:
   ```bash
   # Web interface
   open http://10.10.0.200
   
   # SSH access
   ssh root@10.10.0.200
   ```

## 🛠️ Customization

### Adding More Nodes

Edit `terraform/terraform.tfvars`:

```hcl
# Add more control planes
control_plane_count = 5
control_plane_vm_ids = [101, 102, 103, 104, 105]
control_plane_ips = ["10.10.0.10", "10.10.0.11", "10.10.0.12", "10.10.0.13", "10.10.0.14"]

# Add more workers
worker_count = 5
worker_vm_ids = [201, 202, 203, 204, 205]
worker_ips = ["10.10.0.20", "10.10.0.21", "10.10.0.22", "10.10.0.23", "10.10.0.24"]
```

### Changing Network Configuration

Update the network variables in `terraform/terraform.tfvars`:

```hcl
talos_network_cidr = "10.20.0.0/24"
talos_network_gateway = "10.20.0.1"
# Update all IP addresses accordingly
```

### Disabling NAT Gateway

Set `enable_nat_gateway = false` in `terraform/terraform.tfvars` if you want to use a different internet access method.

## 🔍 Troubleshooting

### Common Issues

1. **OpenTofu Module Not Found**:
   ```bash
   cd environments/dev/terraform
   tofu init
   ```

2. **Proxmox API Issues**:
   - Verify Proxmox API URL and credentials
   - Check if Proxmox node is accessible
   - Ensure storage pools exist

3. **Network Issues**:
   - Verify IP addresses are not in use
   - Check if bridge vmbr1 exists
   - Ensure OpenWrt image is available

4. **Storage Pool Issues**:
   - Verify storage pools exist in Proxmox
   - Check available disk space
   - Ensure proper permissions

### Logs

- **OpenTofu**: Check `tofu apply` output for detailed error messages
- **Proxmox**: Check Proxmox logs for VM creation issues
- **Talos**: Use `talosctl logs` to check node status
- **OpenWrt**: SSH to NAT gateway and check system logs

## 📚 Additional Resources

- [Talos Linux Documentation](https://www.talos.dev/)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [OpenWrt Documentation](https://openwrt.org/docs/start)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)

