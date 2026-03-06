# Migration Guide: Direct ISO → Packer + Vagrant

This guide helps you migrate from the old single-Vagrantfile approach to the new Packer + Vagrant workflow.

## What Changed?

### Before (Direct ISO)
```
environments/local/
├── Vagrantfile              # Deployed VM from ISO directly
├── build-iso.sh             # Built unattended ISO
└── quickstart.sh            # Ran vagrant up with ISO
```

**Issues**:
- Every `vagrant up` took 30-45 minutes (full install from ISO)
- No reusable template for quick rebuilds
- Slow iteration when testing changes

### After (Packer + Vagrant)
```
environments/local/
├── packer/                  # NEW: Build templates
│   ├── build.sh
│   └── proxmox-pve02.pkr.hcl
├── vagrant/                 # NEW: Deploy from templates
│   ├── deploy.sh
│   └── Vagrantfile
├── build-iso.sh             # Still used by Packer
└── quickstart.sh            # Updated to guide workflow
```

**Benefits**:
- Build template once (30-45 min)
- Deploy VMs in 5-10 min from template
- Fast iteration for testing
- Consistent base across deployments

## Migration Steps

### 1. Clean Up Existing VM (Optional)

If you have a running VM from the old workflow:

```bash
cd environments/local

# Check status
vagrant status

# Destroy if you want to start fresh
vagrant destroy -f

# The old Vagrantfile is backed up as Vagrantfile.old-direct-iso
```

### 2. Understand the New Workflow

**Two-Phase Approach**:
1. **Packer Phase**: Build a template (one time or when base needs updating)
2. **Vagrant Phase**: Deploy VMs from template (repeatedly, quickly)

### 3. Build Your First Template

```bash
cd environments/local/packer
./build.sh
```

This will:
- Check prerequisites (Packer, QEMU)
- Build the unattended ISO (if needed)
- Create a VM template using Packer
- Output: `templates/proxmox-pve02.qcow2`
- Time: 30-45 minutes

**Note**: This is a one-time operation. You only rebuild when:
- First time setup
- Updating base Proxmox version
- Changing template configuration

### 4. Deploy VM from Template

```bash
cd environments/local/vagrant
./deploy.sh
```

This will:
- Check prerequisites (Vagrant, libvirt)
- Convert Packer template to Vagrant box
- Deploy VM from template
- Output: Running Proxmox VM at 192.168.56.149
- Time: 5-10 minutes

**This is your main workflow**: Destroy and redeploy as needed for testing.

### 5. Using the Quick Start

For an interactive workflow:

```bash
cd environments/local
./quickstart.sh
```

This script will:
- Check if template exists
- Guide you through build or deploy
- Handle both first-time and repeat workflows

## Common Workflows

### First-Time Setup
```bash
cd environments/local
./quickstart.sh  # Choose option 1 (build + deploy)
```

### Daily Development (Template Exists)
```bash
cd environments/local/vagrant
vagrant destroy -f  # Clean slate
vagrant up          # Fast deploy (5-10 min)
```

### Update Base Template
```bash
# When Proxmox updates or you change base config
cd environments/local/packer
./build.sh

# Then redeploy
cd ../vagrant
vagrant box remove proxmox-pve02-local --force
./deploy.sh
```

## Vagrant Command Changes

Most Vagrant commands now run from `vagrant/` directory:

```bash
# Old workflow
cd environments/local
vagrant up
vagrant ssh
vagrant destroy

# New workflow
cd environments/local/vagrant
vagrant up
vagrant ssh
vagrant destroy
```

Or use the quick start:
```bash
cd environments/local
./quickstart.sh  # Handles directory navigation
```

## File Location Changes

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `./Vagrantfile` | `vagrant/Vagrantfile` | Deploy-specific config |
| N/A | `packer/proxmox-pve02.pkr.hcl` | New template builder |
| `./quickstart.sh` | Same | Updated for new workflow |
| `./build-iso.sh` | Same | Still used, called by Packer |

## Customization Changes

### Adjusting VM Resources

**Old Way** (edit `Vagrantfile`):
```ruby
libvirt.memory = 32768
libvirt.cpus = 8
```

**New Way** (two options):

1. **Vagrant-level** (quick, per-deployment in `vagrant/Vagrantfile`):
   ```ruby
   libvirt.memory = 32768
   libvirt.cpus = 8
   ```

2. **Template-level** (persistent, in `packer/proxmox-pve02.pkr.hcl`):
   ```hcl
   variable "memory" {
     default = 20480
   }
   ```
   Then rebuild template.

### Changing Network Settings

Edit `vagrant/Vagrantfile` (same as before):
```ruby
pve.vm.network "private_network",
  ip: "192.168.56.149",
  libvirt__network_name: "homelab-local"
```

## Troubleshooting Migration

### Issue: Vagrant commands fail with "box not found"

**Solution**:
```bash
# Template exists but not added as Vagrant box
cd environments/local/vagrant
./deploy.sh  # This will add the box
```

### Issue: Old VM conflicts with new deployment

**Solution**:
```bash
# Check libvirt VMs
virsh list --all

# Remove old VM
virsh destroy <vm-name>
virsh undefine <vm-name> --remove-all-storage

# Try deployment again
cd environments/local/vagrant
./deploy.sh
```

### Issue: "Template not found" error

**Solution**:
```bash
# Build the template first
cd environments/local/packer
./build.sh
```

### Issue: Want to go back to old workflow

**Solution**:
```bash
cd environments/local

# Old Vagrantfile is backed up
mv Vagrantfile.old-direct-iso Vagrantfile

# Use old workflow
vagrant up  # Takes 30-45 min with ISO
```

## FAQ

### Q: Do I need to keep the unattended ISO?

**A**: The ISO is automatically built by Packer when needed. You can delete it to save space (~1.3GB), and it will be rebuilt on next Packer run.

### Q: How much disk space does this use?

**A**: 
- Packer template: ~10GB (compressed qcow2)
- Vagrant box: ~10GB (duplicate when added)
- Running VM: ~220GB (grows as used)
- Total: ~240GB vs ~220GB for old workflow

### Q: Can I use the old workflow still?

**A**: Yes, the old `Vagrantfile` is backed up as `Vagrantfile.old-direct-iso`. Restore it if needed. However, the Packer+Vagrant approach is recommended for faster iteration.

### Q: When should I rebuild the template?

**A**: 
- Monthly for security updates
- When Proxmox releases major versions
- When changing base system configuration
- Otherwise, reuse existing template

### Q: Can I deploy multiple VMs from one template?

**A**: Yes! Edit `vagrant/Vagrantfile` to define multiple VMs. Each will be created quickly from the same template.

### Q: What if Packer build fails?

**A**: 
1. Check prerequisites (Packer, QEMU, nested virt)
2. Review build logs in `packer/*.log`
3. Fall back to old workflow if urgent
4. Report issue for investigation

## Rollback Plan

If you need to completely rollback:

```bash
cd environments/local

# Remove new directories
rm -rf packer/ vagrant/

# Restore old Vagrantfile
mv Vagrantfile.old-direct-iso Vagrantfile

# Restore old quickstart (if backed up)
git checkout quickstart.sh README.md

# Use old workflow
./quickstart.sh
```

## Getting Help

- **Packer issues**: See `packer/README.md`
- **Vagrant issues**: See `vagrant/README.md`
- **General workflow**: See main `README.md`
- **Old workflow reference**: Check `Vagrantfile.old-direct-iso`

## Next Steps

After successful migration:

1. Test the new workflow
2. Verify VM functionality
3. Run Ansible playbooks as before
4. Report any issues or suggestions
5. Update documentation with your findings
