# Local Development Environment - Setup Guide

This guide will walk you through setting up the Vagrant-based Proxmox VE local development environment.

## What Was Created

The local environment includes:

```
environments/local/
├── Vagrantfile                              # Main Vagrant configuration
├── quickstart.sh                            # Automated setup script
├── README.md                                # Comprehensive documentation
├── .envrc                                   # Environment variables (direnv)
├── .gitignore                               # Git ignore patterns
├── ansible/
│   ├── inventory/
│   │   └── hosts.toml                       # Ansible inventory
│   ├── host_vars/pve02/
│   │   ├── 00-general.yaml                  # General configuration
│   │   ├── 03-proxmox.yaml                  # Proxmox settings
│   │   ├── 04-talos.yaml                    # Talos cluster config
│   │   └── 99-secrets.sops.yaml.example     # Example secrets file
│   └── group_vars/
│       ├── all/main.yaml                    # Global variables
│       └── local/main.yaml                  # Local env variables
└── terraform/
    ├── main.tf                              # Terraform main config
    ├── variables.tf                         # Variable definitions
    ├── data-sources.tf                      # Ansible integration
    └── terraform.tfvars.example             # Example variables
```

## Quick Start

### Method 1: Automated (Recommended)

```bash
cd /home/lpi/git/Homelab/environments/local
./quickstart.sh
```

This script will:
- Check all prerequisites
- Verify nested virtualization support
- Start Vagrant VM provisioning
- Display next steps

### Method 2: Manual

```bash
cd /home/lpi/git/Homelab/environments/local

# Start Vagrant VM
vagrant up

# Wait 15-30 minutes for provisioning to complete
```

## VM Specifications

The Vagrant VM is configured with:

| Resource | Specification | Adjustable |
|----------|--------------|------------|
| RAM | 32GB | Yes (edit Vagrantfile) |
| CPUs | 8 cores | Yes (edit Vagrantfile) |
| Disk | 220GB | Yes (edit Vagrantfile) |
| IP Address | 192.168.56.149 | Yes (edit Vagrantfile) |
| Network | libvirt private network | Yes |
| Nested Virt | Enabled | Required |

### Adjusting Resources

Edit `Vagrantfile` and modify:

```ruby
config.vm.provider "libvirt" do |libvirt|
  libvirt.memory = 16384  # Change RAM (MB)
  libvirt.cpus = 4        # Change CPU cores
  libvirt.machine_virtual_size = 120  # Change disk (GB)
end
```

Then reload:
```bash
vagrant reload
```

## Post-Deployment Configuration

### 1. Access Proxmox Web Interface

Open browser: `https://192.168.56.149:8006`

**Default Credentials:**
- Username: `root`
- Password: `vagrant`

⚠️ **Important**: Change the root password immediately!

### 2. Change Root Password

```bash
vagrant ssh
sudo passwd root
# Enter new password
exit
```

### 3. Create Encrypted Secrets File

```bash
cd /home/lpi/git/Homelab/environments/local/ansible/host_vars/pve02

# Copy example file
cp 99-secrets.sops.yaml.example 99-secrets.sops.yaml

# Edit with your actual passwords
# Use the new root password you just set
nano 99-secrets.sops.yaml

# Encrypt with SOPS
sops --config ../../../../shared/configs/sops.yaml --encrypt -i 99-secrets.sops.yaml
```

The secrets file should contain:
```yaml
proxmox_user: "automation"
proxmox_password: "your-strong-password"
proxmox_role_name: "AutomationRole"
root_password: "your-new-root-password"
```

### 4. Run Ansible Playbooks

From the repository root:

```bash
cd /home/lpi/git/Homelab

# Set environment
export ANSIBLE_ENVIRONMENT=local

# 1. Post-install configuration
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/00-post-install-pve.yml \
  --limit pve02

# 2. Setup ZFS storage
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/01-zfs-setup.yml \
  --limit pve02

# 3. Create VM templates
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/02-create-vm-template.yml \
  --limit pve02

# 4. Deploy Talos Kubernetes cluster
ansible-playbook \
  -i environments/local/ansible/inventory \
  shared/ansible/playbooks/03-deploy-talos-cluster.yml \
  --limit pve02
```

### 5. Deploy with Terraform (Alternative)

```bash
cd /home/lpi/git/Homelab/environments/local/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (or use Ansible data source)
nano terraform.tfvars

# Plan deployment
terraform plan

# Apply (deploy Talos cluster)
terraform apply
```

## Verification

### Check Proxmox Status

```bash
vagrant ssh

# Check Proxmox services
sudo systemctl status pveproxy
sudo systemctl status pvedaemon
sudo systemctl status pve-cluster

# Check ZFS
sudo zpool status

# Check network
ip addr show vmbr0
```

### Check Talos Cluster

After deploying with Terraform or Ansible:

```bash
# Kubeconfig should be created
export KUBECONFIG=/home/lpi/git/Homelab/environments/local/kubeconfig

# Check cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Common Operations

### Start/Stop VM

```bash
# Start
vagrant up

# Stop (graceful shutdown)
vagrant halt

# Suspend (save state)
vagrant suspend

# Resume
vagrant resume

# Restart
vagrant reload
```

### SSH Access

```bash
# Using Vagrant
vagrant ssh

# Direct SSH (after adding your key)
ssh root@192.168.56.149

# View SSH config
vagrant ssh-config
```

### Destroy and Rebuild

```bash
# Complete rebuild
vagrant destroy -f
vagrant up

# Rebuild with provisioning
vagrant destroy -f && vagrant up --provision
```

### Update Proxmox

```bash
vagrant ssh
sudo apt update
sudo apt upgrade -y
sudo reboot
```

## Networking

### Default Configuration

- **Management Network**: `192.168.56.0/24` (libvirt)
  - Proxmox: `192.168.56.149`
  - Gateway: `192.168.56.1`
  - Talos VIP: `192.168.56.200`
  - Control plane: `192.168.56.201+`
  - Workers: `192.168.56.210+`

- **NAT Network**: `eth0` (Vagrant default, for internet)

### Access VMs from Host

All VMs created inside Proxmox are accessible from your host machine at `192.168.56.x` addresses.

### Bridge to LAN (Optional)

To make VMs accessible from your entire LAN:

1. Edit `Vagrantfile`:
```ruby
config.vm.network "public_network",
  dev: "br0",  # Your bridge interface
  mode: "bridge"
```

2. Reload: `vagrant reload`

## Troubleshooting

### VM Won't Start

```bash
# Check libvirt
sudo systemctl status libvirtd

# Check Vagrant status
vagrant status

# View logs
vagrant up --debug
```

### Nested Virtualization Not Working

```bash
# Check CPU support
egrep -c '(vmx|svm)' /proc/cpuinfo

# Check if enabled (Intel)
cat /sys/module/kvm_intel/parameters/nested

# Check if enabled (AMD)
cat /sys/module/kvm_amd/parameters/nested

# Enable if needed
# Intel:
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1

# AMD:
sudo modprobe -r kvm_amd
sudo modprobe kvm_amd nested=1
```

### Network Issues

```bash
# Restart libvirt network
sudo virsh net-destroy homelab-local
sudo virsh net-start homelab-local

# Or recreate
sudo virsh net-destroy homelab-local
sudo virsh net-undefine homelab-local
vagrant reload
```

### Proxmox Web UI Not Accessible

```bash
vagrant ssh

# Restart Proxmox services
sudo systemctl restart pveproxy
sudo systemctl restart pvedaemon

# Check firewall
sudo iptables -L
```

### SOPS Decryption Fails

```bash
# Verify age key exists
ls -la ~/.config/sops/age/keys.txt

# Test decryption
sops decrypt environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml

# Check SOPS config
cat shared/configs/sops.yaml
```

## Integration with CI/CD

Use the local environment for:

1. **Pre-commit testing**: Test playbooks before committing
   ```bash
   pre-commit run --all-files
   ```

2. **Infrastructure changes**: Test Terraform changes locally
   ```bash
   cd environments/local/terraform
   terraform plan
   ```

3. **Cluster upgrades**: Test Talos/Kubernetes upgrades
   ```bash
   talosctl upgrade --nodes 192.168.56.201
   ```

4. **Application testing**: Deploy and test apps locally
   ```bash
   kubectl apply -f manifests/
   ```

## Resource Management

### Monitor Host Resources

```bash
# Check memory
free -h

# Check CPU
top

# Check disk
df -h

# Check libvirt resources
sudo virsh list --all
sudo virsh pool-list
```

### Optimize for Lower Resources

If you have limited RAM/CPU, edit `Vagrantfile`:

```ruby
# Minimal configuration (16GB RAM, 4 CPUs)
libvirt.memory = 16384
libvirt.cpus = 4
```

And adjust Talos cluster size in `04-talos.yaml`:

```yaml
talos_control_plane_count: 1
talos_control_plane_memory: 2048
talos_worker_count: 1
talos_worker_memory: 2048
```

## Comparison with Other Environments

| Feature | Local | Dev | Prod |
|---------|-------|-----|------|
| Provider | Vagrant (KVM) | Bare metal | Bare metal |
| IP Range | 192.168.56.x | 192.168.0.x | TBD |
| Purpose | Local testing | Integration testing | Production |
| Persistence | Ephemeral | Persistent | Persistent |
| Cluster Size | 1 CP + 2 workers | Full size | Full size |
| Backups | Disabled | Enabled | Enabled |
| Monitoring | Minimal | Full | Full |

## Best Practices

1. **Snapshot before major changes**:
   ```bash
   virsh snapshot-create-as homelab-local_pve02 "before-change"
   ```

2. **Regular rebuilds**: Destroy and recreate monthly to test IaC

3. **Keep secrets separate**: Never commit unencrypted secrets

4. **Document changes**: Update this guide with your findings

5. **Test before prod**: Always test changes in local before dev/prod

## Next Steps

1. ✅ VM provisioned and running
2. ✅ Proxmox accessible via web UI
3. ⬜ Root password changed
4. ⬜ Secrets file created and encrypted
5. ⬜ Ansible playbooks executed
6. ⬜ ZFS storage configured
7. ⬜ VM templates created
8. ⬜ Talos cluster deployed
9. ⬜ Kubernetes accessible
10. ⬜ Test application deployed

## Getting Help

- **Vagrant Issues**: https://www.vagrantup.com/docs
- **Proxmox Documentation**: https://pve.proxmox.com/wiki/Main_Page
- **Talos Documentation**: https://www.talos.dev/docs/
- **Repository Issues**: Check main README.md

---

**Happy Hacking! 🚀**
