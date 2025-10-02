# VM Template Management with Packer

This document describes the new VM template management system using Packer, orchestrated by Ansible.

## Overview

The VM template creation has been moved from Terraform to Packer for better template management and consistency. Templates are created using Packer configurations and orchestrated through Ansible playbooks.

## Architecture

```
Ansible Playbooks
├── 02-create-vm-template.yml    # Creates VM templates with Packer
├── 03-deploy-terraform.yml      # Deploys VMs using Packer-created templates
└── 02-deploy-proxmox-infrastructure.yml  # Updated to verify templates

Packer Configurations
├── shared/packer/talos/talos-template.pkr.hcl
└── shared/packer/openwrt/openwrt-template.pkr.hcl

Terraform
└── environments/dev/terraform/  # Updated to use Packer templates
```

## Template Types

### Talos Template
- **Name**: `talos-template`
- **Purpose**: Kubernetes cluster nodes
- **OS**: Talos Linux
- **Default Resources**: 2GB RAM, 2 CPU cores, 20GB disk
- **Version**: Configurable via `talos_version` variable

### OpenWrt Template
- **Name**: `openwrt-template`
- **Purpose**: Network appliances
- **OS**: OpenWrt
- **Default Resources**: 512MB RAM, 1 CPU core, 4GB disk
- **Version**: Configurable via `openwrt_version` variable

## Usage

### 1. Create VM Templates

Run the template creation playbook:

```bash
ansible-playbook shared/ansible/playbooks/02-create-vm-template.yml -i environments/dev/ansible/inventory/hosts.toml
```

This playbook will:
- Download required ISOs (Talos and OpenWrt)
- Build VM templates using Packer
- Verify template creation
- Set facts for other playbooks

### 2. Deploy VMs with Terraform

Run the Terraform deployment playbook:

```bash
ansible-playbook shared/ansible/playbooks/03-deploy-terraform.yml -i environments/dev/ansible/inventory/hosts.toml
```

This playbook will:
- Verify required templates exist
- Deploy VMs using Terraform
- Use Packer-created templates

### 3. Complete Infrastructure Deployment

Run the full infrastructure deployment:

```bash
ansible-playbook shared/ansible/playbooks/02-deploy-proxmox-infrastructure.yml -i environments/dev/ansible/inventory/hosts.toml
```

## Configuration

### Ansible Variables

Template configuration is managed through Ansible variables in `environments/dev/ansible/host_vars/pve02/03-proxmox.yaml`:

```yaml
vm_templates:
  talos:
    name: "talos-template"
    memory: 2048
    cores: 2
    disk_size: "20G"
    network_bridge: "vmbr0"
    version: "1.8.0"
  openwrt:
    name: "openwrt-template"
    memory: 512
    cores: 1
    disk_size: "4G"
    network_bridge: "vmbr0"
    version: "23.05.3"

# Default VM configuration
vm_template: "talos-template"
vm_memory: 2048
vm_cores: 2
vm_disk_size: "20G"
vm_network: "vmbr0"
vm_tags: "kubernetes,talos"
```

### Terraform Variables

Template overrides can be specified in Terraform:

```hcl
variable "vm_template_override" {
  description = "Override VM template from Ansible (must be Packer-created template)"
  type        = string
  default     = null
}
```

## Prerequisites

1. **Packer**: Must be installed on the control machine
2. **Proxmox**: Storage pools must be configured
3. **Network**: Internet access for ISO downloads
4. **Storage**: Sufficient space for templates and VMs

## Storage Requirements

- **ISO Storage**: `/var/lib/vz/template/iso/` (for downloaded ISOs)
- **Template Storage**: Configured storage pool (default: `storage-vms`)
- **VM Storage**: Same storage pool as templates

## Troubleshooting

### Template Creation Fails

1. Check Packer installation:
   ```bash
   packer version
   ```

2. Verify Proxmox connectivity:
   ```bash
   curl -k https://proxmox-host:8006/api2/json/version
   ```

3. Check storage pool availability:
   ```bash
   pvesm status
   ```

### Template Not Found

1. Verify template exists:
   ```bash
   qm list --full
   ```

2. Re-run template creation:
   ```bash
   ansible-playbook shared/ansible/playbooks/02-create-vm-template.yml
   ```

### VM Deployment Fails

1. Check template availability
2. Verify Terraform configuration
3. Check Proxmox API credentials

## Customization

### Adding New Templates

1. Create Packer configuration in `shared/packer/<template-name>/`
2. Update Ansible variables
3. Add template verification to playbooks

### Modifying Existing Templates

1. Update Packer configuration
2. Update Ansible variables
3. Re-run template creation playbook

## Security Considerations

- Templates are created with minimal configuration
- Sensitive data is managed through Ansible Vault
- Proxmox API credentials are encrypted
- Templates are created in isolated environments

## Performance Optimization

- Templates are created with optimal resource allocation
- Disk images are compressed and optimized
- Network configuration is pre-configured
- Cloud-init is enabled for rapid deployment

## Monitoring

Template creation and VM deployment status is logged and displayed through Ansible output. Check playbook execution logs for detailed information.