# Local Development Environment

This directory contains a Packer + Vagrant workflow for local development that replicates the production Proxmox VE infrastructure on your local machine using KVM/libvirt.

## Overview

The local environment uses a two-step workflow:

1. **Packer** (`packer/`): Builds a reusable Proxmox VE VM template from unattended ISO
2. **Vagrant** (`vagrant/`): Deploys VMs quickly from the Packer-built template

### Why Packer + Vagrant?

- **Build once, deploy many**: Template creation takes 30-45 min, but deployment is 5-10 min
- **Consistent environments**: Same base template ensures reproducibility
- **Rapid iteration**: Quickly destroy and recreate VMs for testing
- **Infrastructure as Code**: Both template and deployment are version controlled

### VM Specifications

The local environment provisions a Proxmox VE hypervisor with:
- **20GB RAM** (configurable based on your host resources)
- **8 CPU cores** (configurable)
- **220GB disk** (matches production)
- **Nested virtualization** enabled (for running Talos VMs inside Proxmox)
- **ZFS storage** (pre-configured via unattended install)

This allows you to test infrastructure changes locally before deploying to dev/staging/prod.

## Prerequisites

### Host System Requirements

- **OS**: Linux with KVM support (Fedora, Ubuntu, Debian, etc.)
- **CPU**: Intel VT-x or AMD-V with nested virtualization support
- **RAM**: 40GB+ recommended (32GB for VM + 8GB for host)
- **Disk**: 250GB+ free space
- **Virtualization**: KVM/QEMU installed and configured

### Software Requirements

1. **Vagrant** (v2.3.0+)
   ```bash
   # Fedora
   sudo dnf install vagrant

   # Ubuntu/Debian
   sudo apt install vagrant
   ```

2. **vagrant-libvirt plugin**
   ```bash
   vagrant plugin install vagrant-libvirt
   ```

3. **libvirt and KVM**
   ```bash
   # Fedora
   sudo dnf install @virtualization
   sudo systemctl enable --now libvirtd

   # Ubuntu/Debian
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   sudo systemctl enable --now libvirtd
   ```

4. **Add your user to libvirt group**
   ```bash
   sudo usermod -a -G libvirt $(whoami)
   # Log out and log back in for group changes to take effect
   ```

5. **Verify nested virtualization is enabled**
   ```bash
   # For Intel CPUs
   cat /sys/module/kvm_intel/parameters/nested
   # Should output: Y or 1

   # For AMD CPUs
   cat /sys/module/kvm_amd/parameters/nested
   # Should output: Y or 1

   # If not enabled, enable it:
   # Intel: echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf
   # AMD: echo "options kvm_amd nested=1" | sudo tee /etc/modprobe.d/kvm.conf
   # Then reboot
   ```

## Quick Start

The fastest way to get started is using the automated quickstart script:

```bash
cd environments/local
./quickstart.sh
```

This interactive script will guide you through:
1. Building the Packer template (first time only)
2. Deploying with Vagrant (fast, repeatable)

### Manual Workflow

#### Option A: Full Workflow (First Time)

```bash
# 1. Build Packer template (30-45 minutes)
cd environments/local/packer
./build.sh

# 2. Deploy with Vagrant (5-10 minutes)
cd ../vagrant
./deploy.sh
```

#### Option B: Deploy Only (Template Exists)

```bash
# If template already exists, just deploy
cd environments/local/vagrant
./deploy.sh
```

### What Gets Created

After the workflow completes:
- Packer template at `packer/templates/proxmox-pve02.qcow2`
- Vagrant box registered as `proxmox-pve02-local`
- Running Proxmox VM at `192.168.56.149:8006`

### 3. Access Proxmox Web Interface

Once deployment completes (~5-10 minutes for Vagrant, longer if template was just built):

1. Open browser: `https://192.168.56.149:8006`
2. Accept self-signed certificate warning
3. Login with:
   - **Username**: `root`
   - **Password**: `vagrantvagrant` (from unattended install)

**Note**: The unattended installation configures everything automatically - no manual steps needed!

### 4. Update Root Password (Recommended)

```bash
vagrant ssh
sudo passwd root
# Enter your desired password
```

Then update the password in your local Ansible secrets:
```bash
# Edit the local environment secrets
sops environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml
```

### 5. Configure with Ansible (Optional)

**Note**: The unattended ISO already configures Proxmox basics (network, ZFS). Ansible playbooks are for additional setup like storage pools, VM templates, and Talos cluster deployment.

Run the Ansible playbooks to complete setup:

```bash
# From repository root
cd /home/lpi/git/Homelab

# Set environment to local
export ANSIBLE_ENVIRONMENT=local

# Run post-install playbook
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/00-post-install-pve.yml \
  --limit pve02

# Setup ZFS storage
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

## VM Management

All VM management is done through Vagrant:

```bash
cd environments/local/vagrant

# Start the VM
vagrant up

# Suspend VM (save state)
vagrant suspend

# Resume from suspended state
vagrant resume

# Shutdown VM
vagrant halt

# Restart VM
vagrant reload

# Destroy VM completely (keeps template for quick rebuild)
vagrant destroy -f

# Check status
vagrant status

# SSH into VM
vagrant ssh
```

### Rebuilding from Template

Fast rebuild cycle (5-10 minutes):

```bash
cd environments/local/vagrant
vagrant destroy -f
vagrant up
```

### Updating the Base Template

If you need to update the base Proxmox template:

```bash
# Rebuild template
cd environments/local/packer
./build.sh

# Remove old box and redeploy
cd ../vagrant
vagrant box remove proxmox-pve02-local --force
./deploy.sh
```

## Directory Structure

```
environments/local/
├── packer/                          # Packer template builder
│   ├── build.sh                     # Build orchestration script
│   ├── proxmox-pve02.pkr.hcl       # Packer template definition
│   ├── README.md                    # Packer documentation
│   ├── templates/                   # Built templates
│   │   └── proxmox-pve02.qcow2     # VM template image
│   └── output-*/                    # Build artifacts (temporary)
│
├── vagrant/                         # Vagrant deployment
│   ├── deploy.sh                    # Deployment orchestration script
│   ├── Vagrantfile                  # Vagrant configuration
│   ├── README.md                    # Vagrant documentation
│   └── .vagrant/                    # Vagrant state (auto-generated)
│
├── ansible/                         # Ansible configuration
│   ├── group_vars/                  # Group variables
│   ├── host_vars/                   # Host-specific variables
│   └── inventory/                   # Inventory files
│
├── terraform/                       # Terraform configuration (future)
├── proxmox/                         # Proxmox answer files
│   └── answer_pve02.toml           # Unattended install config
│
├── build-iso.sh                     # ISO builder script
├── quickstart.sh                    # Interactive quick start
├── README.md                        # This file
└── proxmox-pve02-unattended.iso    # Built unattended ISO
```

### Workflow Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `packer/build.sh` | Build VM template | First time, or when base changes |
| `vagrant/deploy.sh` | Deploy VM from template | Every time you need a VM |
| `quickstart.sh` | Interactive workflow | When unsure what to do |
| `build-iso.sh` | Build unattended ISO | Automatically called by Packer |

## Troubleshooting

### VM won't start

```bash
# Check libvirt status
sudo systemctl status libvirtd

# Check for conflicting VMs
virsh list --all

# View Vagrant logs
vagrant up --debug
```

### Nested virtualization not working

```bash
# Verify nested virt is enabled
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should be > 0

# Check KVM modules
lsmod | grep kvm

# For Intel
cat /sys/module/kvm_intel/parameters/nested

# For AMD
cat /sys/module/kvm_amd/parameters/nested
```

### Network issues

```bash
# Restart libvirt network
sudo virsh net-destroy homelab-local
sudo virsh net-start homelab-local

# Or restart entire libvirt
sudo systemctl restart libvirtd
```

### Proxmox web interface not accessible

```bash
vagrant ssh

# Check Proxmox services
sudo systemctl status pveproxy
sudo systemctl status pvedaemon
sudo systemctl status pve-cluster

# Restart if needed
sudo systemctl restart pveproxy
```

## Comparison: Packer+Vagrant vs Direct ISO

| Aspect | Packer + Vagrant | Direct ISO Only |
|--------|-----------------|-----------------|
| **Initial Setup** | 30-45 min (Packer build) | 30-45 min (Vagrant up) |
| **Subsequent Deploys** | 5-10 min (from template) | 30-45 min (full install) |
| **Consistency** | Guaranteed (same template) | Variable (depends on ISO) |
| **Flexibility** | Template + Vagrant config | Full customization per run |
| **Disk Usage** | ~230GB (template + VM) | ~220GB (VM only) |
| **Best For** | Rapid iteration & testing | One-time local setup |

**Recommendation**: Use Packer + Vagrant for development where you'll frequently rebuild VMs.

## Integration with CI/CD

The local environment can be used for:

1. **Pre-commit testing**: Test Ansible playbooks before committing
2. **Template testing**: Verify VM templates work correctly
3. **Cluster testing**: Deploy full Talos cluster locally
4. **Disaster recovery testing**: Practice backup/restore procedures
5. **Upgrade testing**: Test Proxmox and Kubernetes upgrades

## Clean Up

### Remove everything

```bash
# Destroy VM
vagrant destroy -f

# Remove libvirt storage
sudo virsh vol-delete --pool default pve02_vagrant_box_image_0.img

# Remove network (if desired)
sudo virsh net-destroy homelab-local
sudo virsh net-undefine homelab-local
```

## Tips & Best Practices

1. **Snapshot before major changes**:
   ```bash
   # Create snapshot
   virsh snapshot-create-as homelab-local_pve02 "before-upgrade" "Before Proxmox upgrade"

   # List snapshots
   virsh snapshot-list homelab-local_pve02

   # Revert to snapshot
   virsh snapshot-revert homelab-local_pve02 "before-upgrade"
   ```

2. **Use separate storage for VMs**: Consider adding an additional virtual disk for ZFS

3. **Resource allocation**: Don't over-commit host resources; leave at least 8GB for your host OS

4. **Regular cleanup**: Periodically destroy and recreate to test "infrastructure as code" from scratch

## Next Steps

After the local environment is running:

1. Test Ansible playbooks against local environment
2. Deploy a minimal Talos cluster
3. Test application deployments
4. Verify backup/restore procedures
5. Document any differences between local and production

## Support

For issues or questions:
- Check the main repository README
- Review Proxmox VE documentation: https://pve.proxmox.com/wiki/Main_Page
- Check Vagrant documentation: https://www.vagrantup.com/docs
