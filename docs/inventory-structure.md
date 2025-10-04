# Inventory Structure Documentation

This document describes the standardized inventory and variable organization for the infrastructure project.

## Directory Structure

```
environments/
├── dev/
│   ├── ansible/
│   │   ├── group_vars/
│   │   │   ├── all/           # Variables for all hosts
│   │   │   ├── dev/           # Common dev environment variables
│   │   │   ├── dev_pve/       # Proxmox-specific variables
│   │   │   └── dev_talos/     # Talos cluster variables
│   │   ├── host_vars/         # Host-specific variables
│   │   └── inventory/
│   │       └── hosts.toml     # Inventory file
│   └── terraform/             # Terraform configuration
└── prod/
    ├── ansible/
    │   ├── group_vars/
    │   │   ├── all/           # Variables for all hosts
    │   │   ├── prod/           # Common prod environment variables
    │   │   ├── prod_pve/      # Proxmox-specific variables
    │   │   ├── prod_talos/    # Talos cluster variables
    │   │   ├── prod_k8s_control/  # Control plane specific
    │   │   └── prod_k8s_workers/  # Worker specific
    │   ├── host_vars/         # Host-specific variables
    │   └── inventory/
    │       └── hosts.toml     # Inventory file
    └── terraform/             # Terraform configuration
```

## Variable Hierarchy and Precedence

Variables are loaded in the following order (later sources override earlier ones):

1. **all/** - Variables for all hosts across all environments
2. **environment/** (dev/, prod/) - Common environment variables
3. **role-specific/** (dev_pve/, dev_talos/, etc.) - Role-specific variables
4. **host_vars/** - Host-specific variables

## Variable Naming Conventions

### Environment Variables
- `environment`: Environment name (dev, prod)
- `domain`: Domain name for the environment
- `datacenter`: Datacenter identifier

### Cluster Variables
- `cluster_name`: Name of the Talos cluster
- `talos_version`: Talos Linux version
- `control_plane_count`: Number of control plane nodes
- `worker_count`: Number of worker nodes

### Network Variables
- `bridge_name`: Network bridge name
- `talos_network_cidr`: CIDR for Talos cluster network
- `talos_network_gateway`: Gateway for Talos cluster network
- `management_network_cidr`: CIDR for management network
- `management_gateway`: Gateway for management network

### Proxmox Variables
- `proxmox_api_url`: Proxmox API URL
- `proxmox_default_storage_pool`: Default storage pool
- `proxmox_user`: Proxmox username
- `proxmox_password`: Proxmox password (sensitive)

### Security Variables
- `enable_firewall`: Enable firewall rules
- `ssh_public_keys`: List of SSH public keys

## Group Organization

### Environment Groups
- **dev/**: Development environment common variables
- **prod/**: Production environment common variables

### Role Groups
- **dev_pve/**, **prod_pve/**: Proxmox host configuration
- **dev_talos/**, **prod_talos/**: Talos cluster configuration
- **prod_k8s_control/**: Control plane specific settings
- **prod_k8s_workers/**: Worker node specific settings

## Best Practices

1. **Single Source of Truth**: Each variable should be defined in only one place
2. **No Redundancy**: Avoid duplicating variables across multiple files
3. **Clear Hierarchy**: Use the variable hierarchy to override values appropriately
4. **Consistent Naming**: Follow the established naming conventions
5. **Documentation**: Document any custom variables in this file
6. **Sensitive Data**: Use SOPS for sensitive variables (passwords, keys)

## Variable Validation

All variables should be validated using the configuration validation playbook:

```bash
ansible-playbook -i environments/dev/ansible/inventory/hosts.toml \
  shared/ansible/playbooks/validate-config.yml
```

## Migration Notes

When migrating from the old structure:
1. Remove `terraform_variables` sections from group_vars
2. Use direct variable passing from Ansible to Terraform
3. Leverage Terraform data sources for dynamic inputs
4. Update variable names to follow conventions
5. Consolidate duplicate variables