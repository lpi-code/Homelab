# Homelab Infrastructure Usage Guide

This guide explains how to use the new environment-first homelab infrastructure with Ansible as the source of truth and dynamic inventory management.

## Quick Start

### Prerequisites

- Python 3.8+
- Ansible 2.9+
- Terraform 1.0+
- Access to Proxmox VE cluster
- SSH access to all target hosts

### Initial Setup

1. **Clone and navigate to repository**
   ```bash
   git clone <repository-url>
   cd homelab
   ```

2. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure SSH access**
   ```bash
   # Add SSH keys to target hosts
   ssh-copy-id root@192.168.1.102
   ssh-copy-id root@192.168.1.110
   # ... for all hosts
   ```

4. **Test dynamic inventory**
   ```bash
   ./shared/ansible/inventory/dynamic_inventory.py --list-environments
   ```

## Dynamic Inventory Management

### Overview

The dynamic inventory system automatically discovers hosts from all environments and provides a unified view while maintaining environment isolation.

### Basic Usage

```bash
# List all available environments
./shared/ansible/inventory/dynamic_inventory.py --list-environments

# List all hosts across all environments
./shared/ansible/inventory/dynamic_inventory.py --list

# List hosts in specific environment
./shared/ansible/inventory/dynamic_inventory.py --list --env dev

# Get variables for specific host
./shared/ansible/inventory/dynamic_inventory.py --host pve02-dev

# Validate all inventory files
./shared/ansible/inventory/dynamic_inventory.py --validate
```

### Advanced Usage

```bash
# Debug mode for troubleshooting
./shared/ansible/inventory/dynamic_inventory.py --list --debug

# Specify custom repository root
./shared/ansible/inventory/dynamic_inventory.py --list --repo-root /path/to/homelab
```

## Environment Management

### Environment Structure

Each environment follows this structure:
```
environments/
├── dev/
│   ├── ansible/
│   │   ├── inventory/hosts.yaml
│   │   ├── group_vars/
│   │   └── host_vars/
│   ├── terraform/
│   ├── kubernetes/
│   └── configs/
├── staging/
│   └── [same structure]
└── prod/
    └── [same structure]
```

### Adding New Hosts

1. **Edit environment inventory file**
   ```yaml
   # environments/dev/ansible/inventory/hosts.yaml
   all:
     children:
       dev:
         children:
           dev_pve:
             hosts:
               new-host:
                 ansible_host: 192.168.1.103
                 ansible_user: root
                 environment: dev
                 cluster_role: pve
                 terraform_vars:
                   proxmox_node: "pve02"
                   storage_pool: "local-zfs"
                   # ... other variables
   ```

2. **Test new host**
   ```bash
   # Verify host is discoverable
   ./shared/ansible/inventory/dynamic_inventory.py --host new-host
   
   # Test connectivity
   ansible new-host -m ping
   ```

### Environment Variables

Environment-specific variables are defined in `group_vars/`:

```yaml
# environments/dev/ansible/group_vars/dev/main.yaml
environment: dev
domain: dev.homelab.local
cluster_name: dev-cluster

network:
  cidr: "192.168.1.0/24"
  gateway: "192.168.1.1"
  dns_servers: ["192.168.1.1", "8.8.8.8"]

proxmox:
  api_url: "https://192.168.1.102:8006"
  storage_pool: "local-zfs"
```

## Ansible Usage

### Basic Commands

```bash
# Ping all hosts
ansible all -m ping

# Ping specific environment
ansible dev -m ping
ansible staging -m ping
ansible prod -m ping

# Ping specific groups
ansible dev_pve -m ping
ansible dev_k8s_control -m ping
ansible dev_services -m ping
```

### Running Playbooks

```bash
# Run shared playbooks
ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev

ansible-playbook shared/ansible/playbooks/kubernetes/talos-bootstrap.yml -e target_environment=dev

ansible-playbook shared/ansible/playbooks/maintenance/backup.yml -e target_environment=dev

# Run with specific hosts
ansible-playbook playbook.yml --limit dev_pve

# Run with extra variables
ansible-playbook playbook.yml -e target_environment=dev -e update_packages=true
```

### Environment Targeting

```bash
# Target all environments
ansible all -m setup

# Target specific environment
ansible dev -m setup

# Target multiple environments
ansible "dev:staging" -m ping

# Target by environment and role
ansible "dev_pve:staging_pve" -m ping
```

## Terraform Integration

### Overview

Terraform integrates with Ansible through external data sources, allowing infrastructure provisioning based on Ansible inventory data.

### Basic Usage

```bash
# Navigate to environment directory
cd environments/dev/terraform

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan -var="target_host=pve02-dev"

# Apply infrastructure
terraform apply -var="target_host=pve02-dev"
```

### Data Source Integration

The `data-sources.tf` file automatically queries Ansible inventory:

```hcl
# Get host information from Ansible
data "external" "ansible_host" {
  program = ["python3", "../../../shared/scripts/terraform/ansible_data_source.py"]
  query = {
    hostname = var.target_host
    environment = var.environment
  }
}

# Use Ansible data in resources
resource "proxmox_vm_qemu" "target_vm" {
  name        = var.target_host
  target_node = local.proxmox_node
  vmid        = local.vm_id
  memory      = local.vm_memory
  cores       = local.vm_cores
  # ... other configuration from Ansible
}
```

### Testing Data Sources

```bash
# Test data source script
./shared/scripts/terraform/ansible_data_source.py --hostname pve02-dev --environment dev

# Test environment listing
./shared/scripts/terraform/ansible_data_source.py --list-environment dev
```

## Shared Components

### Shared Playbooks

Located in `shared/ansible/playbooks/`:

- **Infrastructure**: Proxmox setup, network configuration
- **Kubernetes**: Talos bootstrap, cluster management
- **Maintenance**: Backup, updates, monitoring

### Shared Roles

Located in `shared/ansible/roles/`:

- **proxmox**: Proxmox VE configuration and management
- **kubernetes**: Kubernetes cluster setup and management
- **monitoring**: Monitoring stack deployment

### Shared Terraform Modules

Located in `shared/terraform/modules/`:

- **network**: Network configuration modules
- **proxmox-vm**: Proxmox VM provisioning modules
- **talos-cluster**: Talos cluster deployment modules
- **monitoring**: Monitoring infrastructure modules

## Best Practices

### Inventory Management

1. **Keep terraform_vars updated**
   - Ensure all Terraform variables are defined in inventory
   - Use consistent naming conventions
   - Document variable purposes

2. **Environment isolation**
   - Don't mix environments in inventory files
   - Use environment-specific variable files
   - Maintain separate Terraform workspaces

3. **Host naming conventions**
   - Use descriptive names: `pve02-dev`, `k8s-cp-01-staging`
   - Include environment in hostname
   - Use consistent role prefixes

### Ansible Usage

1. **Use environment targeting**
   ```bash
   # Good: Target specific environment
   ansible dev -m ping
   
   # Avoid: Target all environments unnecessarily
   ansible all -m ping
   ```

2. **Leverage shared playbooks**
   ```bash
   # Use shared playbooks for common tasks
   ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev
   ```

3. **Use variables effectively**
   ```bash
   # Pass environment variables
   ansible-playbook playbook.yml -e target_environment=dev -e cluster_name=my-cluster
   ```

### Terraform Usage

1. **Use Ansible data sources**
   - Always query Ansible for host information
   - Don't duplicate configuration in Terraform
   - Use local values to parse Ansible data

2. **Environment-specific workspaces**
   ```bash
   # Use separate workspaces for each environment
   terraform workspace select dev
   terraform plan -var="target_host=pve02-dev"
   ```

3. **State management**
   - Use separate state files per environment
   - Consider remote state backends for production
   - Regular state backups

## Troubleshooting

### Dynamic Inventory Issues

```bash
# Check script permissions
ls -la shared/ansible/inventory/dynamic_inventory.py

# Test script directly
./shared/ansible/inventory/dynamic_inventory.py --list

# Check Python dependencies
python3 -c "import yaml, json, pathlib"

# Debug mode
./shared/ansible/inventory/dynamic_inventory.py --list --debug
```

### Ansible Connectivity Issues

```bash
# Test SSH connectivity
ssh root@192.168.1.102

# Check SSH keys
ssh-add -l

# Verbose output
ansible all -m ping -vvv

# Check Ansible configuration
ansible-config dump
```

### Terraform Data Source Issues

```bash
# Test data source script
./shared/scripts/terraform/ansible_data_source.py --hostname pve02-dev --environment dev

# Check script permissions
ls -la shared/scripts/terraform/ansible_data_source.py

# Check Python path
which python3
```

### Common Error Messages

1. **"No hosts matched"**
   - Check inventory file syntax
   - Verify host exists in correct environment
   - Check dynamic inventory script

2. **"Connection refused"**
   - Verify SSH connectivity
   - Check SSH keys
   - Verify host is running

3. **"Data source error"**
   - Check Ansible data source script
   - Verify host exists in inventory
   - Check script permissions

## Advanced Usage

### Custom Inventory Scripts

You can extend the dynamic inventory system:

```python
# Custom inventory script
import json
from shared.ansible.inventory.dynamic_inventory import DynamicInventory

inventory = DynamicInventory()
result = inventory.get_inventory(environment="dev")
print(json.dumps(result, indent=2))
```

### Custom Terraform Data Sources

Extend Terraform integration:

```hcl
# Custom data source
data "external" "custom_ansible_data" {
  program = ["python3", "custom_data_source.py"]
  query = {
    hostname = var.target_host
    custom_param = var.custom_value
  }
}
```

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.9'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Validate inventory
        run: ./shared/ansible/inventory/dynamic_inventory.py --validate
      
      - name: Deploy to dev
        run: |
          ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml \
            -e target_environment=dev
```

## Support and Maintenance

### Regular Tasks

1. **Update dependencies**
   ```bash
   pip install -r requirements.txt --upgrade
   ```

2. **Validate inventory**
   ```bash
   ./shared/ansible/inventory/dynamic_inventory.py --validate
   ```

3. **Test connectivity**
   ```bash
   ansible all -m ping
   ```

4. **Backup configurations**
   ```bash
   ansible-playbook shared/ansible/playbooks/maintenance/backup.yml -e target_environment=dev
   ```

### Monitoring

- Monitor Ansible playbook execution
- Track Terraform state changes
- Monitor host connectivity
- Validate inventory consistency

### Updates

- Keep Ansible and Terraform updated
- Update shared playbooks and roles
- Update inventory with new hosts
- Maintain documentation