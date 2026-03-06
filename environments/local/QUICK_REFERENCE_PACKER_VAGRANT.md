# Quick Reference: Packer + Vagrant Workflow

## 🚀 Quick Start Commands

### Interactive (Recommended for First Time)
```bash
cd environments/local
./quickstart.sh
```

### Build Template (One Time)
```bash
cd environments/local/packer
./build.sh
# ⏱ Time: 30-45 minutes
# 📦 Output: templates/proxmox-pve02.qcow2
```

### Deploy VM (Repeated Use)
```bash
cd environments/local/vagrant
./deploy.sh
# ⏱ Time: 5-10 minutes
# 🌐 Access: https://192.168.56.149:8006
```

## 📋 Common Operations

### Deploy New VM
```bash
cd environments/local/vagrant
vagrant up
```

### Access VM
```bash
# Web Interface
open https://192.168.56.149:8006
# User: root, Pass: vagrant

# SSH
vagrant ssh
```

### Stop VM
```bash
vagrant halt       # Shutdown
vagrant suspend    # Save state
```

### Destroy and Recreate
```bash
vagrant destroy -f
vagrant up         # Fast: 5-10 min from template
```

### Rebuild Template
```bash
cd environments/local/packer
./build.sh
# Then redeploy VM
cd ../vagrant
vagrant box remove proxmox-pve02-local --force
./deploy.sh
```

## 🗂️ Directory Structure

```
local/
├── packer/           ← Build templates here
│   └── build.sh
├── vagrant/          ← Deploy VMs here
│   └── deploy.sh
└── quickstart.sh     ← Start here if unsure
```

## ⏱️ Time Estimates

| Operation | Time |
|-----------|------|
| Build template (Packer) | 30-45 min |
| Deploy VM (Vagrant) | 5-10 min |
| Destroy VM | 1 min |
| Rebuild VM | 5-10 min |

## 🔄 Typical Development Cycle

```bash
# One-time setup
cd packer && ./build.sh              # 30-45 min

# Daily development (from vagrant/)
vagrant up                           # 5-10 min
# ... test changes ...
vagrant destroy -f && vagrant up     # 5-10 min
# Repeat as needed!
```

## 📚 Documentation

| File | Purpose |
|------|---------|
| `README.md` | Overview & getting started |
| `packer/README.md` | Template building guide |
| `vagrant/README.md` | VM deployment guide |
| `MIGRATION.md` | Migration from old workflow |
| `WORKFLOW-DIAGRAM.txt` | Visual workflow guide |

## 🆘 Troubleshooting Quick Fixes

### Template not found
```bash
cd environments/local/packer
./build.sh
```

### Vagrant box not found
```bash
cd environments/local/vagrant
./deploy.sh  # Will add box automatically
```

### VM won't start
```bash
sudo systemctl restart libvirtd
cd environments/local/vagrant
vagrant destroy -f
vagrant up
```

### Network issues
```bash
sudo virsh net-destroy homelab-local
sudo virsh net-start homelab-local
vagrant reload
```

## 🎯 When to Use What

| Scenario | Command | Where |
|----------|---------|-------|
| First time | `./quickstart.sh` | `local/` |
| Need template | `./build.sh` | `packer/` |
| Need VM | `./deploy.sh` | `vagrant/` |
| Daily work | `vagrant up` | `vagrant/` |
| Clean slate | `vagrant destroy -f` | `vagrant/` |

## 🔧 Configuration Files

| File | Purpose | Edit When |
|------|---------|-----------|
| `packer/proxmox-pve02.pkr.hcl` | Template config | Changing base system |
| `vagrant/Vagrantfile` | VM config | Changing VM resources |
| `proxmox/answer_pve02.toml` | Install config | Changing Proxmox setup |

## ✅ Prerequisites

- Packer 1.9.0+
- Vagrant 2.3.0+
- vagrant-libvirt plugin
- QEMU/KVM
- Nested virtualization enabled

Check with: `./quickstart.sh` (includes prerequisite checks)

## 💾 Disk Space

| Item | Size |
|------|------|
| Packer template | ~10 GB |
| Vagrant box | ~10 GB |
| Running VM | ~220 GB |
| Total needed | ~240 GB |

## 🌐 Network Details

- Network: `homelab-local` (192.168.56.0/24)
- Proxmox IP: `192.168.56.149`
- Gateway: `192.168.56.1`

## 🔐 Default Credentials

- **Username**: root
- **Password**: vagrantvagrant
- **⚠️ Change after first login!**

## 🔄 Ansible Integration

After VM deployment, run Ansible playbooks as usual:

```bash
cd /home/lpi/git/Homelab
export ANSIBLE_ENVIRONMENT=local
ansible-playbook -i environments/local/ansible/inventory \
  shared/ansible/playbooks/00-post-install-pve.yml --limit pve02
```

## 📞 Getting Help

1. Check `README.md` in each directory
2. Run `./quickstart.sh` for interactive guide
3. Read `MIGRATION.md` for migration issues
4. See `WORKFLOW-DIAGRAM.txt` for visual guide

## 🔙 Rollback to Old Workflow

```bash
cd environments/local
mv Vagrantfile.old-direct-iso Vagrantfile
vagrant up  # Uses old ISO-based workflow
```
