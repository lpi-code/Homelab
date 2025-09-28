# Homelab Infrastructure Migration Guide

This guide provides step-by-step instructions for migrating from the old infrastructure structure to the new environment-first organization with Ansible as the source of truth.

## Overview

The new structure implements:
- **Environment-first organization** (dev, staging, prod)
- **Dynamic inventory management** with automatic discovery
- **Ansible as source of truth** for all host configurations
- **Terraform integration** through external data sources
- **Shared components** across environments

## Migration Steps

### Phase 1: Backup Current State

1. **Backup existing configurations**
   ```bash
   # Create backup directory
   mkdir -p backup/$(date +%Y%m%d)
   
   # Backup existing inventory
   cp -r infrastructure/ansible backup/$(date +%Y%m%d)/ 2>/dev/null || true
   
   # Backup existing Terraform configs
   cp -r infrastructure/terraform backup/$(date +%Y%m%d)/ 2>/dev/null || true
   ```

2. **Document current inventory**
   ```bash
   # Export current host list
   ansible all --list-hosts > backup/$(date +%Y%m%d)/current-hosts.txt
   
   # Export current variables
   ansible all -m setup > backup/$(date +%Y%m%d)/current-facts.json
   ```

### Phase 2: Test New Structure

1. **Test dynamic inventory script**
   ```bash
   # List all environments
   ./shared/ansible/inventory/dynamic_inventory.py --list-environments
   
   # List all hosts
   ./shared/ansible/inventory/dynamic_inventory.py --list
   
   # List specific environment
   ./shared/ansible/inventory/dynamic_inventory.py --list --env dev
   
   # Get host-specific variables
   ./shared/ansible/inventory/dynamic_inventory.py --host pve02-dev
   ```

2. **Validate inventory files**
   ```bash
   # Validate all inventory files
   ./shared/ansible/inventory/dynamic_inventory.py --validate
   ```

3. **Test Ansible connectivity**
   ```bash
   # Test connectivity to all hosts
   ansible all -m ping
   
   # Test connectivity to specific environment
   ansible dev -m ping
   ```

### Phase 3: Migrate Existing Configurations

1. **Extract current inventory data**
   ```bash
   # If you have existing inventory, extract host data
   # Update the environment-specific inventory files with your actual host data
   ```

2. **Update host variables**
   - Review `environments/*/ansible/inventory/hosts.yaml`
   - Update IP addresses, hostnames, and terraform_vars
   - Ensure all required fields are present

3. **Migrate Terraform configurations**
   ```bash
   # Copy existing Terraform configs to environment directories
   # Update variables and data sources
   ```

### Phase 4: Update References

1. **Update scripts and automation**
   - Update any scripts that reference old paths
   - Update CI/CD pipelines
   - Update documentation

2. **Update team workflows**
   - Train team on new structure
   - Update runbooks and procedures
   - Update monitoring and alerting

### Phase 5: Validation and Testing

1. **Test dynamic inventory**
   ```bash
   # Verify all hosts are discoverable
   ansible all --list-hosts
   
   # Verify environment targeting works
   ansible dev --list-hosts
   ansible staging --list-hosts
   ansible prod --list-hosts
   ```

2. **Test Terraform integration**
   ```bash
   cd environments/dev/terraform
   terraform init
   terraform plan
   ```

3. **Test shared playbooks**
   ```bash
   # Test Proxmox setup
   ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev
   
   # Test Talos bootstrap
   ansible-playbook shared/ansible/playbooks/kubernetes/talos-bootstrap.yml -e target_environment=dev
   ```

## New Structure Usage

### Dynamic Inventory Usage

```bash
# List all environments
./shared/ansible/inventory/dynamic_inventory.py --list-environments

# List all hosts across environments
./shared/ansible/inventory/dynamic_inventory.py --list

# List hosts in specific environment
./shared/ansible/inventory/dynamic_inventory.py --list --env dev

# Get host-specific variables
./shared/ansible/inventory/dynamic_inventory.py --host pve02-dev

# Validate inventory
./shared/ansible/inventory/dynamic_inventory.py --validate

# Debug mode
./shared/ansible/inventory/dynamic_inventory.py --list --debug
```

### Ansible Usage

```bash
# Target all environments
ansible all -m ping

# Target specific environment
ansible dev -m ping
ansible staging -m ping
ansible prod -m ping

# Target specific groups within environment
ansible dev_pve -m ping
ansible dev_k8s -m ping
ansible dev_services -m ping

# Run playbooks with environment targeting
ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev
```

### Terraform Usage

```bash
# Navigate to environment directory
cd environments/dev/terraform

# Initialize Terraform
terraform init

# Plan with Ansible integration
terraform plan -var="target_host=pve02-dev"

# Apply infrastructure
terraform apply -var="target_host=pve02-dev"
```

## Troubleshooting

### Common Issues

1. **Dynamic inventory not working**
   ```bash
   # Check script permissions
   ls -la shared/ansible/inventory/dynamic_inventory.py
   
   # Test script directly
   ./shared/ansible/inventory/dynamic_inventory.py --list
   
   # Check Python dependencies
   python3 -c "import yaml, json"
   ```

2. **Host not found in inventory**
   ```bash
   # Check inventory file exists
   ls -la environments/dev/ansible/inventory/hosts.yaml
   
   # Validate YAML syntax
   python3 -c "import yaml; yaml.safe_load(open('environments/dev/ansible/inventory/hosts.yaml'))"
   
   # Check host variables format
   ```

3. **Terraform data source errors**
   ```bash
   # Test data source script
   ./shared/scripts/terraform/ansible_data_source.py --hostname pve02-dev --environment dev
   
   # Check script permissions
   ls -la shared/scripts/terraform/ansible_data_source.py
   ```

4. **Ansible connectivity issues**
   ```bash
   # Test SSH connectivity
   ssh root@192.168.1.102
   
   # Check SSH keys
   ssh-add -l
   
   # Test with verbose output
   ansible all -m ping -vvv
   ```

### Debug Commands

```bash
# Enable debug mode for dynamic inventory
./shared/ansible/inventory/dynamic_inventory.py --list --debug

# Enable verbose Ansible output
ansible all -m ping -vvv

# Test Terraform data source with debug
./shared/scripts/terraform/ansible_data_source.py --hostname pve02-dev --environment dev --debug

# Check Ansible configuration
ansible-config dump
```

## Rollback Procedure

If issues occur during migration:

1. **Restore from backup**
   ```bash
   # Restore original ansible.cfg
   cp backup/$(date +%Y%m%d)/ansible.cfg .
   
   # Restore original inventory
   cp -r backup/$(date +%Y%m%d)/infrastructure/ansible .
   ```

2. **Revert Ansible configuration**
   ```bash
   # Update ansible.cfg to use old inventory
   # Test connectivity
   ansible all -m ping
   ```

3. **Document issues**
   - Record what went wrong
   - Identify root causes
   - Plan fixes before retry

## Post-Migration Tasks

1. **Clean up old structure**
   ```bash
   # Remove old directories (after confirming everything works)
   rm -rf infrastructure/ansible
   rm -rf infrastructure/terraform
   ```

2. **Update documentation**
   - Update README.md
   - Update team documentation
   - Update monitoring dashboards

3. **Train team**
   - Conduct training sessions
   - Update runbooks
   - Share best practices

## Support

For issues or questions:
1. Check this migration guide
2. Review the main README.md
3. Check troubleshooting section
4. Create issue in repository