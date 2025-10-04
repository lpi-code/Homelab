# Talos Linux Packer Template

This directory contains Packer configuration for building Talos Linux VM templates on Proxmox.

## Prerequisites

1. **Packer** installed (version >= 1.8.0)
2. **Proxmox Packer plugin** installed
3. **Proxmox API access** with appropriate permissions
4. **Proxmox storage** configured for templates and ISOs

## Installation

### Install Packer

```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install packer

# On CentOS/RHEL
sudo yum install packer

# Or download from HashiCorp
wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
unzip packer_1.9.4_linux_amd64.zip
sudo mv packer /usr/local/bin/
```

### Install Proxmox Packer Plugin

```bash
packer init .
```

## Configuration

### Environment Variables

Set the following environment variables:

```bash
export PKR_VAR_proxmox_token="your-proxmox-api-token"
export PKR_VAR_proxmox_node="pve02"
export PKR_VAR_proxmox_storage_pool="local-zfs"
export PKR_VAR_talos_version="1.9.5"
```

### Variables File

Create a `variables.auto.pkr.hcl` file:

```hcl
proxmox_token = "your-proxmox-api-token"
proxmox_node = "pve02"
proxmox_storage_pool = "local-zfs"
talos_version = "1.9.5"
template_name = "talos-linux"
```

## Usage

### Build Template

```bash
# Initialize Packer
packer init .

# Validate configuration
packer validate .

# Build template
packer build .

# Build with specific variables
packer build -var="talos_version=1.9.5" -var="proxmox_node=pve02" .
```

### Build with Variables File

```bash
packer build -var-file="variables.auto.pkr.hcl" .
```

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `talos_version` | Talos Linux version to build | `1.9.5` | No |
| `proxmox_node` | Proxmox node to build on | `pve02` | No |
| `proxmox_storage_pool` | Storage pool for template | `local-zfs` | No |
| `proxmox_iso_pool` | Storage pool for ISOs | `storage-isos` | No |
| `proxmox_username` | Proxmox username | `root@pam` | No |
| `proxmox_token` | Proxmox API token | - | Yes |
| `proxmox_url` | Proxmox API URL | `https://pve02.homelab.local:8006/api2/json` | No |
| `template_name` | Name for created template | `talos-linux` | No |
| `template_description` | Template description | `Talos Linux template built with Packer` | No |
| `vm_memory` | Build VM memory (MB) | `2048` | No |
| `vm_cores` | Build VM CPU cores | `2` | No |
| `vm_disk_size` | Build VM disk size | `20G` | No |
| `network_bridge` | Network bridge | `vmbr0` | No |

## Output

The build process will create a Proxmox VM template named `talos-linux-v{version}` that can be used by Terraform modules to deploy Talos VMs.

## Troubleshooting

### Common Issues

1. **SSL Certificate Issues**: Set `insecure_skip_tls_verify = true` in the source configuration
2. **Storage Pool Issues**: Ensure the storage pool exists and has sufficient space
3. **Network Issues**: Verify the network bridge exists and is accessible
4. **API Token Issues**: Ensure the token has appropriate permissions for VM creation

### Debug Mode

Run Packer in debug mode for detailed output:

```bash
PACKER_LOG=1 packer build .
```

## Integration with Terraform

This template is designed to work with the `talos-vm` Terraform module. The template name should match the `template_name` variable in the Terraform module.


