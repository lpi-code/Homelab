# Local Development Environment - Quick Reference

## 🚀 Getting Started (First Time)

```bash
cd /home/lpi/git/Homelab/environments/local

# Build unattended Proxmox ISO (one time, ~10 minutes)
./build-iso.sh

# Deploy VM with Vagrant (~20 minutes)
vagrant up

# Access Proxmox
# https://192.168.56.149:8006
# root / vagrant
```

## 📋 Common Commands

### VM Management

```bash
# Start VM
vagrant up

# Stop VM
vagrant halt

# Restart VM
vagrant reload

# Destroy VM
vagrant destroy -f

# SSH into VM
vagrant ssh

# VM status
vagrant status
```

### ISO Management

```bash
# Rebuild ISO
./build-iso.sh

# Rebuild and redeploy
./build-iso.sh && vagrant destroy -f && vagrant up
```

### Ansible

```bash
cd /home/lpi/git/Homelab

# Post-install configuration
ansible-playbook -i environments/local/ansible/inventory \
  shared/ansible/playbooks/00-post-install-pve.yml --limit pve02

# Setup ZFS
ansible-playbook -i environments/local/ansible/inventory \
  shared/ansible/playbooks/01-zfs-setup.yml --limit pve02
```

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `proxmox/answer_pve02.toml` | Proxmox installation config |
| `Vagrantfile` | VM resources and networking |
| `ansible/host_vars/pve02/` | Ansible configuration |
| `.envrc` | Environment variables |

## 🌐 Network Details

- **Proxmox IP**: 192.168.56.149
- **Network**: 192.168.56.0/24 (libvirt)
- **Gateway**: 192.168.56.1
- **DNS**: 192.168.56.1

## 💾 VM Resources

- **RAM**: 32GB (edit Vagrantfile to adjust)
- **CPUs**: 8 cores
- **Disk**: 220GB
- **Nested Virt**: Enabled

## 🔑 Default Credentials

- **Username**: root
- **Password**: vagrant
- **SSH Key**: Configured from answer file

⚠️ **Change password after first login!**

## 📦 What Gets Installed

The unattended ISO automatically installs:
- ✅ Proxmox VE 9.1
- ✅ ZFS filesystem
- ✅ Network configuration (static IP)
- ✅ SSH keys
- ✅ Basic system packages

## 🎯 Typical Workflow

1. **First time setup:**
   ```bash
   ./quickstart.sh  # Builds ISO + deploys VM
   ```

2. **Daily usage:**
   ```bash
   vagrant up       # Start VM
   # Work in Proxmox web UI
   vagrant halt     # Stop VM when done
   ```

3. **Testing changes:**
   ```bash
   # Edit answer file
   vim proxmox/answer_pve02.toml

   # Rebuild and redeploy
   ./build-iso.sh
   vagrant destroy -f && vagrant up
   ```

## 🐛 Troubleshooting

### ISO build fails
```bash
# Check Docker
docker info

# Check disk space
df -h

# Clean Docker cache
docker system prune -af
```

### VM won't start
```bash
# Check libvirt
sudo systemctl status libvirtd

# Check nested virt
cat /sys/module/kvm_intel/parameters/nested

# Destroy and recreate
vagrant destroy -f && vagrant up
```

### Can't access web UI
```bash
# Check VM is running
vagrant status

# Check Proxmox service
vagrant ssh
systemctl status pveproxy
```

## 📚 Documentation

- [README.md](./README.md) - Full guide
- [README-ISO.md](./README-ISO.md) - ISO details
- [SETUP_GUIDE.md](./SETUP_GUIDE.md) - Step-by-step
- [../../docs/deployment/README-setup-unatend-proxmox.md](../../docs/deployment/README-setup-unatend-proxmox.md) - Script docs

## 🔗 Useful URLs

- Proxmox Web: https://192.168.56.149:8006
- Proxmox Docs: https://pve.proxmox.com/wiki/
- Vagrant Docs: https://www.vagrantup.com/docs

## 💡 Tips

- Use `./quickstart.sh` for automated setup
- ISO is cached in `~/.cache/nanokvm-isos/`
- Customize `proxmox/answer_pve02.toml` for your needs
- VM can be accessed from host at 192.168.56.149
- Use `vagrant suspend` for quick pause/resume
