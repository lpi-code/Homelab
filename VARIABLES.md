# Infrastructure Variables Documentation

This document provides comprehensive documentation for all variables used in the infrastructure project, their precedence, validation rules, and sensitive variable handling.

## Variable Precedence

Variables are loaded in the following order (later sources override earlier ones):

1. **Ansible group_vars/all/** - Global variables for all environments
2. **Ansible group_vars/environment/** (dev/, prod/) - Environment-specific variables
3. **Ansible group_vars/role-specific/** (dev_talos/, prod_talos/, etc.) - Role-specific variables
4. **Ansible host_vars/** - Host-specific variables
5. **Terraform data sources** - Dynamic variables from Ansible
6. **Terraform locals** - Computed values

## Core Variables

### Environment Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `environment` | string | - | Environment name (dev, prod) | Must be "dev" or "prod" |
| `domain` | string | - | Domain name for the environment | Valid domain format |
| `datacenter` | string | - | Datacenter identifier | Non-empty string |

### Cluster Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `cluster_name` | string | - | Name of the Talos cluster | Non-empty string |
| `talos_version` | string | - | Talos Linux version | Format: X.Y.Z (e.g., 1.9.5) |
| `control_plane_count` | number | - | Number of control plane nodes | 1-5 nodes |
| `worker_count` | number | - | Number of worker nodes | 0 or greater |

### Control Plane Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `control_plane_vm_ids` | list(number) | - | VM IDs for control plane nodes | Unique IDs 1-9999 |
| `control_plane_ips` | list(string) | - | IP addresses for control plane nodes | Valid IP addresses |
| `control_plane_cores` | number | - | CPU cores per control plane node | 1-32 cores |
| `control_plane_memory` | number | - | Memory per control plane node (MB) | 1GB-128GB |
| `control_plane_disk_size` | string | - | Disk size per control plane node | Format: "50G", "100G" |

### Worker Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `worker_vm_ids` | list(number) | - | VM IDs for worker nodes | Unique IDs 1-9999 |
| `worker_ips` | list(string) | - | IP addresses for worker nodes | Valid IP addresses |
| `worker_cores` | number | - | CPU cores per worker node | 1-32 cores |
| `worker_memory` | number | - | Memory per worker node (MB) | 1GB-128GB |
| `worker_disk_size` | string | - | Disk size per worker node | Format: "100G", "200G" |

### Network Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `bridge_name` | string | - | Network bridge name | Format: vmbrX |
| `talos_network_cidr` | string | - | CIDR for Talos cluster network | Valid CIDR block |
| `talos_network_gateway` | string | - | Gateway for Talos cluster network | Valid IP address |
| `management_network_cidr` | string | - | CIDR for management network | Valid CIDR block |
| `management_gateway` | string | - | Gateway for management network | Valid IP address |

### NAT Gateway Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `enable_nat_gateway` | bool | - | Enable NAT gateway | true/false |
| `nat_gateway_vm_id` | number | - | VM ID for NAT gateway | 1-9999 |
| `nat_gateway_management_ip` | string | - | Management IP for NAT gateway | Valid IP with CIDR |
| `nat_gateway_cluster_ip` | string | - | Cluster IP for NAT gateway | Valid IP with CIDR |
| `nat_gateway_password` | string | - | Root password for OpenWrt | Min 8 characters |
| `openwrt_version` | string | - | OpenWrt version | Format: X.Y.Z |

### Proxmox Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `proxmox_node` | string | - | Proxmox node name | Non-empty string |
| `proxmox_api_url` | string | - | Proxmox API URL | Valid HTTPS URL |
| `proxmox_user` | string | - | Proxmox username | Non-empty string |
| `proxmox_password` | string | - | Proxmox password | **SENSITIVE** |
| `proxmox_tls_insecure` | bool | true | Skip TLS verification | true/false |
| `storage_pool` | string | - | Proxmox storage pool | Non-empty string |
| `iso_pool` | string | - | Storage pool for ISO images | Non-empty string |

### Security Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `enable_firewall` | bool | - | Enable firewall rules | true/false |
| `ssh_public_keys` | list(string) | - | SSH public keys | Must start with 'ssh-' |

### Storage Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `openwrt_template_file_id` | string | - | OpenWrt template file ID | Format: 'pool:path' |
| `talos_image_file_id` | string | - | Talos image file ID | Format: 'pool:path' |

### Tunnel Configuration

| Variable | Type | Default | Description | Validation |
|----------|------|---------|-------------|-----------|
| `control_plane_tunnel_ports` | list(number) | - | Control plane tunnel ports | 1025-65535 |
| `worker_tunnel_ports` | list(number) | - | Worker tunnel ports | 1025-65535 |

## Computed Variables (Terraform Locals)

These variables are computed from other variables and don't need to be set directly:

| Variable | Type | Description | Source |
|----------|------|-------------|--------|
| `environment` | string | Environment name | Hardcoded in locals |
| `proxmox_user` | string | Proxmox username | Hardcoded in locals |
| `proxmox_tls_insecure` | bool | Skip TLS verification | Hardcoded in locals |
| `proxmox_api_url` | string | Proxmox API URL | Computed from proxmox_node |
| `tunnel_local_port` | number | Local tunnel port | Hardcoded in locals |
| `nat_gateway_password` | string | NAT gateway password | Hardcoded in locals |
| `nat_gateway_memory` | number | NAT gateway memory | Hardcoded in locals |
| `nat_gateway_cores` | number | NAT gateway cores | Hardcoded in locals |

## Sensitive Variables

The following variables contain sensitive information and should be encrypted with SOPS:

- `proxmox_password`
- `nat_gateway_password`
- `ssh_private_keys` (if used)

### SOPS Encryption

Sensitive variables should be stored in encrypted files:

```bash
# Encrypt a file
sops -e -i environments/dev/ansible/group_vars/all/secrets.sops.yaml

# Edit encrypted file
sops environments/dev/ansible/group_vars/all/secrets.sops.yaml
```

## Environment-Specific Defaults

### Development Environment
- `cluster_name`: "dev-talos"
- `talos_version`: "1.9.5"
- `control_plane_count`: 3
- `worker_count`: 3
- `bridge_name`: "vmbr1"
- `talos_network_cidr`: "10.10.0.0/24"

### Production Environment
- `cluster_name`: "prod-talos"
- `talos_version`: "1.9.5"
- `control_plane_count`: 3
- `worker_count`: 5
- `bridge_name`: "vmbr3"
- `talos_network_cidr`: "192.168.3.0/24"

## Variable Validation

All variables are validated using Terraform validation blocks and Ansible validation playbooks:

### Terraform Validation
- Type checking
- Range validation for numeric values
- Format validation for strings
- CIDR validation for network addresses

### Ansible Validation
Run the validation playbook to check variable consistency:

```bash
ansible-playbook -i environments/dev/ansible/inventory/hosts.toml \
  shared/ansible/playbooks/validate-config.yml
```

## Migration Guide

When migrating from the old variable structure:

1. **Remove terraform_variables sections** from group_vars files
2. **Use direct variable passing** from Ansible to Terraform via data sources
3. **Update variable names** to follow the standardized conventions
4. **Consolidate duplicate variables** into single sources
5. **Add validation blocks** for critical variables
6. **Encrypt sensitive variables** with SOPS

## Troubleshooting

### Common Issues

1. **Variable not found**: Check variable precedence and ensure it's defined in the correct group_vars file
2. **Validation errors**: Verify variable format and range constraints
3. **SOPS decryption errors**: Ensure SOPS keys are properly configured
4. **Data source errors**: Verify the Ansible variable extraction script is working correctly

### Debug Commands

```bash
# Test Ansible variable extraction
python3 shared/scripts/get-ansible-vars.py --environment dev --host pve02 --format json

# Validate Terraform configuration
terraform validate

# Check Ansible variable consistency
ansible-playbook -i environments/dev/ansible/inventory/hosts.toml \
  shared/ansible/playbooks/validate-config.yml
```