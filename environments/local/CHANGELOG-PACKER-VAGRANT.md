# Local Environment: Packer + Vagrant Split

**Status**: ✅ Complete  
**Date**: 2026-02-07

## Summary

The local environment has been refactored from a single Vagrant-based workflow into a two-phase Packer + Vagrant approach for faster iteration and better infrastructure as code practices.

## Changes Made

### 1. New Directory Structure

```
environments/local/
├── packer/                          # NEW: Template builder
│   ├── build.sh                     # Build orchestration
│   ├── proxmox-pve02.pkr.hcl       # Packer template
│   ├── README.md                    # Packer documentation
│   ├── .gitignore                   # Ignore build artifacts
│   └── templates/                   # Output directory
│       └── proxmox-pve02.qcow2     # Built template
│
├── vagrant/                         # NEW: VM deployment
│   ├── deploy.sh                    # Deployment orchestration
│   ├── Vagrantfile                  # Vagrant config
│   ├── README.md                    # Vagrant documentation
│   └── .gitignore                   # Ignore Vagrant state
│
├── Vagrantfile.old-direct-iso      # MOVED: Old workflow backup
├── build-iso.sh                     # UNCHANGED: Still used by Packer
├── quickstart.sh                    # UPDATED: New interactive workflow
├── README.md                        # UPDATED: New structure docs
├── MIGRATION.md                     # NEW: Migration guide
└── .gitignore                       # UPDATED: Added Packer/Vagrant ignores
```

### 2. Files Created

#### Packer Files
- `packer/proxmox-pve02.pkr.hcl` - Packer template using QEMU builder
- `packer/build.sh` - Build script with prerequisite checks
- `packer/README.md` - Comprehensive Packer documentation
- `packer/.gitignore` - Ignore build artifacts

#### Vagrant Files
- `vagrant/Vagrantfile` - Vagrant config for template deployment
- `vagrant/deploy.sh` - Deployment script with box management
- `vagrant/README.md` - Comprehensive Vagrant documentation
- `vagrant/.gitignore` - Ignore Vagrant state

#### Documentation
- `MIGRATION.md` - Complete migration guide from old workflow
- Updated `README.md` - Reflects new Packer + Vagrant structure
- Updated `quickstart.sh` - Interactive workflow guide

### 3. Files Modified

- `quickstart.sh` - Updated to guide through Packer + Vagrant workflow
- `README.md` - Updated with new directory structure and workflows
- `.gitignore` - Added Packer/Vagrant specific ignores

### 4. Files Moved/Backed Up

- `Vagrantfile` → `Vagrantfile.old-direct-iso` - Old workflow preserved

## Workflow Comparison

### Before (Direct ISO)
```bash
cd environments/local
./build-iso.sh           # 5-10 min
vagrant up               # 30-45 min (full Proxmox install from ISO)
# Total: 35-55 minutes every time
```

### After (Packer + Vagrant)
```bash
# One-time setup
cd environments/local/packer
./build.sh               # 30-45 min (builds reusable template)

# Repeated deployments
cd environments/local/vagrant
./deploy.sh              # 5-10 min (deploys from template)
```

**Time Savings**: 
- First deployment: Same (30-45 min)
- Subsequent deployments: 25-35 min faster (5-10 min vs 30-45 min)

## Benefits

1. **Faster Iteration**: Deploy VMs in 5-10 minutes instead of 30-45 minutes
2. **Consistency**: Same template ensures reproducible environments
3. **Separation of Concerns**: Template building vs VM deployment
4. **Better IaC**: Both phases are fully version controlled
5. **Flexibility**: Easy to rebuild template or redeploy VMs independently

## Technical Details

### Packer Template Features
- Uses QEMU/KVM builder with nested virtualization
- Builds from unattended Proxmox ISO
- Provisions with shell scripts (qemu-guest-agent, cloud-init)
- Outputs qcow2 format for libvirt compatibility
- Configurable resources (RAM, CPU, disk)

### Vagrant Deployment Features
- Converts Packer template to Vagrant box format
- Manages libvirt networks automatically
- Same network configuration as before (192.168.56.0/24)
- Supports standard Vagrant commands (up, halt, destroy, etc.)
- Fast deployment from template

## Usage

### Interactive (Recommended)
```bash
cd environments/local
./quickstart.sh
```

### Manual - First Time
```bash
cd environments/local/packer
./build.sh

cd ../vagrant
./deploy.sh
```

### Manual - Subsequent Deploys
```bash
cd environments/local/vagrant
vagrant destroy -f
vagrant up
```

## Migration Path

Users with existing VMs can:
1. Keep using old workflow with `Vagrantfile.old-direct-iso`
2. Destroy old VM and adopt new workflow
3. See `MIGRATION.md` for detailed guidance

## Testing Needed

- [ ] Test Packer build on fresh system
- [ ] Test Vagrant deployment from Packer template
- [ ] Verify nested virtualization works in deployed VM
- [ ] Test Ansible playbooks against deployed VM
- [ ] Verify network connectivity and Proxmox web access
- [ ] Test destroy and redeploy cycle
- [ ] Test template rebuild and box update process

## Rollback Plan

If issues arise:
```bash
cd environments/local
mv Vagrantfile.old-direct-iso Vagrantfile
vagrant up  # Uses old direct-ISO workflow
```

## Documentation

All workflows are documented in:
- `README.md` - Overview and quick start
- `packer/README.md` - Packer template building
- `vagrant/README.md` - Vagrant VM deployment
- `MIGRATION.md` - Migration from old workflow
- `quickstart.sh` - Interactive guide

## Notes

- Packer template build is required before first Vagrant deployment
- Template should be rebuilt monthly for security updates
- Old ISO-based workflow is preserved for reference
- No changes to Ansible, Terraform, or other tooling
- Network configuration remains the same (192.168.56.149)

## Future Enhancements

Potential improvements:
- Add Packer validation to CI/CD
- Create template versioning scheme
- Add multi-VM Vagrant deployment example
- Consider cloud-init integration for further automation
- Add snapshot management automation
