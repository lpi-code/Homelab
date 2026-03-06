# Vagrant Deployment Directory

This directory contains Vagrant configuration for deploying Proxmox VE from the Packer-built template.

## Overview

This Vagrant setup provides rapid deployment of Proxmox VE environments using pre-built templates:
- **Fast deployment**: 5-10 minutes (vs 30-45 minutes from ISO)
- **Template-based**: Uses Packer-built qcow2 images
- **Consistent**: Same configuration every time
- **Flexible**: Easy to destroy and recreate

## Prerequisites

### Required

1. **Vagrant** (v2.3.0+)
2. **vagrant-libvirt plugin**
3. **libvirt/KVM**
4. **Packer template** (built by `../packer/build.sh`)

See main README for installation instructions.

## Quick Start

### 1. Build Packer Template (First Time Only)

```bash
cd ../packer
./build.sh
```

This creates the template at `../packer/templates/proxmox-pve02.qcow2`

### 2. Deploy with Vagrant

```bash
cd environments/local/vagrant
./deploy.sh
```

This will:
1. Check prerequisites
2. Verify Packer template exists
3. Add template as Vagrant box (if needed)
4. Create libvirt network
5. Deploy VM from template
6. Takes 5-10 minutes

### 3. Access Proxmox

Once deployed:
- **Web**: https://192.168.56.149:8006
- **User**: root
- **Pass**: vagrant

```bash
# SSH into VM
vagrant ssh
```

## Vagrant Commands

### Basic Operations

```bash
# Start VM (first time or after destroy)
vagrant up

# Stop VM gracefully
vagrant halt

# Suspend VM (save state)
vagrant suspend

# Resume from suspended state
vagrant resume

# Restart VM
vagrant reload

# Destroy VM completely
vagrant destroy -f

# Check VM status
vagrant status

# SSH into VM
vagrant ssh

# Re-run provisioners
vagrant provision
```

### Box Management

```bash
# List installed boxes
vagrant box list

# Remove box (to rebuild from template)
vagrant box remove proxmox-pve02-local --provider libvirt

# Update box (after rebuilding template)
cd ../packer && ./build.sh
cd ../vagrant && ./deploy.sh
# Choose to re-add box when prompted
```

## Configuration

### Resource Adjustment

Edit `Vagrantfile` to change VM resources:

```ruby
libvirt.memory = 20480  # RAM in MB (20GB default)
libvirt.cpus = 8        # CPU cores (8 default)
```

Then reload:
```bash
vagrant reload
```

### Network Configuration

Default network setup:
- **Management**: 192.168.56.0/24 (homelab-local)
- **Proxmox IP**: 192.168.56.149
- **Gateway**: 192.168.56.1

To modify, edit the `network` section in `Vagrantfile`.

## Deployment Workflow

### Development Cycle

1. **Build template** (once or when base changes):
   ```bash
   cd ../packer && ./build.sh
   ```

2. **Deploy VM** (quick, repeatable):
   ```bash
   cd ../vagrant && ./deploy.sh
   ```

3. **Test changes**:
   ```bash
   vagrant ssh
   # Make changes, test configurations
   ```

4. **Recreate if needed**:
   ```bash
   vagrant destroy -f && vagrant up
   ```

### Template Updates

When you need to rebuild the base template:

```bash
# Destroy current VM
cd environments/local/vagrant
vagrant destroy -f

# Rebuild template
cd ../packer
./build.sh

# Re-deploy from new template
cd ../vagrant
vagrant box remove proxmox-pve02-local --force
./deploy.sh
```

## Comparison: Vagrant vs Direct ISO

| Aspect | Vagrant (Template) | Direct ISO |
|--------|-------------------|------------|
| **First-time setup** | 30-45 min (Packer) | 30-45 min |
| **Subsequent deploys** | 5-10 min | 30-45 min |
| **Consistency** | Guaranteed | Variable |
| **Flexibility** | Template + config | Full customization |
| **Best for** | Rapid testing | Initial setup |

## Integration with Ansible

After Vagrant deployment, use Ansible for configuration:

```bash
# From repository root
cd /home/lpi/git/Homelab
export ANSIBLE_ENVIRONMENT=local

# Post-install configuration
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/00-post-install-pve.yml \
  --limit pve02

# Setup ZFS
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/01-zfs-setup.yml \
  --limit pve02

# Create VM templates
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/02-create-vm-template.yml \
  --limit pve02

# Deploy Talos cluster
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/03-deploy-talos-cluster.yml \
  --limit pve02
```

## Troubleshooting

### VM Won't Start

```bash
# Check Vagrant status
vagrant status

# Try with debug output
vagrant up --debug

# Check libvirt
sudo systemctl status libvirtd
virsh list --all

# Check for port conflicts
sudo lsof -i :8006
```

### Template Not Found

```bash
# Verify template exists
ls -lh ../packer/templates/proxmox-pve02.qcow2

# If missing, build it
cd ../packer
./build.sh
```

### Network Issues

```bash
# Check network status
sudo virsh net-list
sudo virsh net-info homelab-local

# Restart network
sudo virsh net-destroy homelab-local
sudo virsh net-start homelab-local

# Check VM network
vagrant ssh
ip addr show
ping 8.8.8.8
```

### SSH Connection Failed

```bash
# Check if VM is running
vagrant status

# Try to SSH manually
vagrant ssh-config
# Use details to SSH directly

# Check if SSH is running in VM
vagrant ssh -c "systemctl status sshd"
```

### Box Add Failed

```bash
# Remove existing box
vagrant box remove proxmox-pve02-local --provider libvirt --force

# Clean up libvirt storage
sudo virsh vol-list default | grep proxmox
# Delete any stale volumes

# Try deploy script again
./deploy.sh
```

### Nested Virtualization Not Working

```bash
# Verify nested virt in host
cat /sys/module/kvm_intel/parameters/nested  # Intel
cat /sys/module/kvm_amd/parameters/nested    # AMD

# Check inside VM
vagrant ssh
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should be > 0

# If not, VM was created before enabling nested virt
# Destroy and recreate:
vagrant destroy -f
vagrant up
```

## Advanced Usage

### Snapshot Management

```bash
# Create snapshot
virsh snapshot-create-as \
  $(virsh list --name | grep pve02) \
  "snapshot-name" \
  "Description"

# List snapshots
virsh snapshot-list $(virsh list --name | grep pve02)

# Revert to snapshot
virsh snapshot-revert \
  $(virsh list --name | grep pve02) \
  "snapshot-name"
```

### Custom Provisioning

Add provisioners to `Vagrantfile`:

```ruby
# Run custom script
pve.vm.provision "shell", path: "scripts/setup.sh"

# Run Ansible from Vagrant
pve.vm.provision "ansible" do |ansible|
  ansible.playbook = "../ansible/playbooks/setup.yml"
  ansible.inventory_path = "../ansible/inventory"
end
```

### Multiple VMs

To deploy multiple Proxmox hosts:

```ruby
# In Vagrantfile
(1..3).each do |i|
  config.vm.define "pve0#{i}" do |pve|
    pve.vm.hostname = "pve0#{i}"
    pve.vm.network "private_network", ip: "192.168.56.14#{i}"
    # ... rest of config
  end
end
```

Then:
```bash
vagrant up pve01
vagrant up pve02
vagrant up pve03
```

## File Structure

```
vagrant/
├── deploy.sh          # Deployment orchestration script
├── Vagrantfile        # Vagrant configuration
├── README.md          # This file
└── .vagrant/          # Vagrant state (auto-generated)
```

## Tips & Best Practices

1. **Use templates for speed**: Rebuild template monthly, deploy daily
2. **Snapshot before changes**: Easy rollback if something breaks
3. **Document customizations**: Keep notes in git commits
4. **Clean up regularly**: `vagrant destroy` to free resources
5. **Test in isolation**: Each developer can have their own local env

## CI/CD Integration

### Automated Testing

```bash
#!/bin/bash
# ci-test.sh

# Deploy VM
cd environments/local/vagrant
./deploy.sh

# Wait for services
sleep 60

# Run tests
vagrant ssh -c "systemctl is-active pveproxy"
curl -k https://192.168.56.149:8006

# Cleanup
vagrant destroy -f
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Test Vagrantfile syntax
cd environments/local/vagrant
vagrant validate

# Test Packer template
cd ../packer
packer validate .
```

## Next Steps

After deployment:
1. Change default root password
2. Configure with Ansible playbooks
3. Deploy test workloads
4. Verify backup/restore procedures
5. Document any issues or improvements

## Support

- Vagrant documentation: https://www.vagrantup.com/docs
- vagrant-libvirt documentation: https://github.com/vagrant-libvirt/vagrant-libvirt
- Proxmox VE documentation: https://pve.proxmox.com/wiki/Main_Page
