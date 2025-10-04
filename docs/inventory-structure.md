# Ansible Inventory Structure Documentation

## Overview

This document describes the standardized inventory structure and variable management system for the Talos cluster deployment.

## Directory Structure

```
environments/dev/ansible/
├── group_vars/
│   ├── all/
│   │   └── secrets.sops.yaml          # Encrypted sensitive values
│   ├── dev/
│   │   └── main.yaml                  # Common dev environment variables
│   ├── dev_pve/
│   │   └── main.yaml                  # Proxmox-specific variables
│   └── dev_talos/
│       └── main.yaml                  # Talos cluster configuration (SINGLE SOURCE OF TRUTH)
├── host_vars/
│   └── pve02/
│       ├── 00-general.yaml           # Host-specific general config
│       ├── 01-storage.yaml           # Storage configuration
│       ├── 02-network.yaml           # Network configuration
│       ├── 03-proxmox.yaml           # Proxmox-specific config
│       ├── 04-talos.yaml             # Talos-specific config
│       └── 99-secrets.sops.yaml      # Host-specific encrypted secrets
└── inventory/
    └── hosts.toml                     # Host definitions
```

## Variable Precedence

Variables are resolved in the following order (highest to lowest precedence):

1. **Host Variables** (`host_vars/pve02/`)
2. **Group Variables** (`group_vars/dev_talos/`)
3. **Parent Group Variables** (`group_vars/dev_pve/`, `group_vars/dev/`)
4. **All Group Variables** (`group_vars/all/`)
5. **Playbook Defaults**

## Single Source of Truth

### `environments/dev/ansible/group_vars/dev_talos/main.yaml`

This file contains the **single source of truth** for all Talos cluster configuration:

```yaml
---
# Cluster Configuration
cluster_name: "dev-talos"
talos_version: "1.9.5"
environment: "dev"

# Node Configuration
control_plane_count: 3
worker_count: 3

# VM Configuration
control_plane_vm_ids: [101, 102, 103]
worker_vm_ids: [201, 202, 203]
control_plane_ips: ["10.10.0.10", "10.10.0.11", "10.10.0.12"]
worker_ips: ["10.10.0.20", "10.10.0.21", "10.10.0.22"]

# Resource Specifications
control_plane_cores: 4
control_plane_memory: 8192
control_plane_disk_size: "50G"
worker_cores: 4
worker_memory: 8192
worker_disk_size: "50G"

# Network Configuration
bridge_name: "vmbr1"
talos_network_cidr: "10.10.0.0/24"
talos_network_gateway: "10.10.0.1"
management_network_cidr: "192.168.0.0/24"
management_gateway: "192.168.0.1"

# NAT Gateway Configuration
enable_nat_gateway: true
nat_gateway_vm_id: 200
nat_gateway_management_ip: "192.168.0.200/24"
nat_gateway_cluster_ip: "10.10.0.200/24"
openwrt_version: "23.05.5"

# Security Configuration
enable_firewall: true
ssh_public_keys:
  - "{{ ansible_user }}@{{ ansible_host }}"

# Additional Configuration
vm_disk_size: "32G"
kubernetes_version: "v1.29.0"
iso_pool: "storage-isos"
```

## Variable Flow

### New Simplified Flow

```
Ansible Inventory Variables (dev_talos/main.yaml)
    ↓
Ansible Playbook (03-deploy-talos-cluster.yml)
    ↓
Direct Variable Passing to Terraform
    ↓
Terraform Modules
```

### Removed Components

- ❌ `terraform_variables` section in `dev_talos/main.yaml`
- ❌ Hardcoded variables in playbook `vars` section
- ❌ Complex Jinja2 template transformations
- ❌ Duplicate variable definitions in `terraform/variables.tf`

## Security

### SOPS Integration

Sensitive values are encrypted using SOPS:

- **Global Secrets**: `group_vars/all/secrets.sops.yaml`
- **Host Secrets**: `host_vars/pve02/99-secrets.sops.yaml`

**Encrypted Variables**:
- `proxmox_user`
- `proxmox_password`
- `proxmox_role_name`
- `root_password`
- Database credentials
- API tokens
- SSL certificates

### Variable Exposure

- ✅ Sensitive values encrypted with SOPS
- ✅ No sensitive data in `terraform.tfvars`
- ✅ Direct variable passing reduces exposure risk
- ✅ Proper variable scoping

## Terraform Integration

### Direct Variable Passing

Variables are now passed directly from Ansible to Terraform:

```yaml
- name: Apply Terraform configuration
  community.general.terraform:
    project_path: "{{ terraform_dir }}"
    variables:
      cluster_name: "{{ cluster_name }}"
      talos_version: "{{ talos_version }}"
      control_plane_count: "{{ control_plane_count }}"
      # ... other variables
```

### Terraform Variables

The `environments/dev/terraform/variables.tf` file now contains:
- Only essential variable definitions
- Consistent defaults aligned with Ansible inventory
- Removed duplicate variables
- Proper validation blocks

## Validation

### Pre-deployment Checks

Before deployment, validate:

1. **Variable Consistency**:
   ```bash
   ansible-playbook validate-config.yml
   ```

2. **SOPS Decryption**:
   ```bash
   sops -d environments/dev/ansible/group_vars/all/secrets.sops.yaml
   ```

3. **Inventory Syntax**:
   ```bash
   ansible-inventory --list -i environments/dev/ansible/inventory/hosts.toml
   ```

## Best Practices

### Adding New Variables

1. **Cluster Configuration**: Add to `dev_talos/main.yaml`
2. **Host-specific**: Add to `host_vars/pve02/`
3. **Sensitive**: Encrypt with SOPS
4. **Document**: Update this file

### Modifying Existing Variables

1. **Update**: `dev_talos/main.yaml` (single source of truth)
2. **Test**: Run validation playbook
3. **Deploy**: Use standard deployment process

### Environment Promotion

To promote changes to production:

1. **Copy**: Variables from `dev_talos/main.yaml` to `prod_talos/main.yaml`
2. **Adjust**: Environment-specific values
3. **Validate**: Run validation checks
4. **Deploy**: Use production deployment process

## Troubleshooting

### Common Issues

1. **Variable Not Found**: Check variable precedence order
2. **SOPS Decryption Failed**: Verify age key is available
3. **Terraform Apply Failed**: Check variable types and values
4. **Inconsistent Defaults**: Ensure all files use same values

### Debug Commands

```bash
# Check variable resolution
ansible-inventory --list -i environments/dev/ansible/inventory/hosts.toml

# Validate SOPS
sops -d environments/dev/ansible/group_vars/all/secrets.sops.yaml

# Test Terraform variables
cd environments/dev/terraform && terraform validate
```

## Migration Notes

### From Old Structure

If migrating from the old structure:

1. **Remove**: `terraform_variables` sections
2. **Consolidate**: All variables in `dev_talos/main.yaml`
3. **Update**: Playbook to use direct variable passing
4. **Test**: Validate configuration before deployment

### Backward Compatibility

- Old `terraform.tfvars` files will still work
- Gradual migration is supported
- Validation helps identify issues

## Conclusion

This new structure provides:
- **Single Source of Truth**: Clear variable definitions
- **Simplified Flow**: Direct variable passing
- **Better Security**: Proper SOPS integration
- **Easier Maintenance**: Reduced complexity
- **Clear Documentation**: This guide

For questions or issues, refer to the troubleshooting section or create an issue in the project repository.