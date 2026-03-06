# Packer Templates Directory

This directory contains Packer templates for building Proxmox VE VM templates for use with libvirt/KVM.

## Overview

Packer automates the creation of a Proxmox VE VM template using:
- Unattended Proxmox ISO (built by `../build-iso.sh`)
- QEMU/KVM hypervisor
- Automated installation and configuration
- Output: libvirt-compatible qcow2 image

## Prerequisites

### Software Requirements

1. **Packer** (v1.9.0+) with QEMU and Vagrant plugins
   ```bash
   # Fedora
   sudo dnf install packer
   
   # Ubuntu/Debian
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install packer
   ```
   Run `packer init .` in this directory to install the QEMU and Vagrant plugins (used for the Vagrant box and optional HCP registry upload).

2. **QEMU/KVM**
   ```bash
   # Fedora
   sudo dnf install @virtualization
   
   # Ubuntu/Debian
   sudo apt install qemu-kvm qemu-utils
   ```

3. **Nested Virtualization** (required for Proxmox)
   ```bash
   # Check if enabled
   cat /sys/module/kvm_intel/parameters/nested  # Intel
   cat /sys/module/kvm_amd/parameters/nested    # AMD
   
   # Enable if needed
   echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf  # Intel
   echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf    # AMD
   # Then reboot
   ```

### System Requirements

- **CPU**: Intel VT-x or AMD-V with nested virtualization
- **RAM**: 24GB+ (20GB for VM + 4GB for host)
- **Disk**: 250GB+ free space
- **Time**: 30-45 minutes for initial build

## Quick Start

### 1. Build the Template

```bash
cd environments/local/packer
./build.sh
```

This script will:
1. Check prerequisites (Packer, QEMU, nested virt)
2. Build unattended Proxmox ISO if not present
3. Initialize Packer plugins (QEMU + Vagrant)
4. Validate Packer template
5. Build the VM template (30-45 minutes)
6. Output: `templates/proxmox-pve02.qcow2` and `templates/proxmox-pve02.box`

### 2. Use with Vagrant

After the template is built:
```bash
cd ../vagrant
./deploy.sh
```

## Template Configuration

### Default Settings

The template is built with these specifications:

| Setting | Value | Description |
|---------|-------|-------------|
| Name | proxmox-pve02 | VM template name |
| Memory | 20GB | RAM allocation |
| CPUs | 8 cores | CPU allocation |
| Disk | 220GB | Disk size (matches prod) |
| Network | 192.168.56.0/24 | Management network |
| IP | 192.168.56.149 | Proxmox IP address |
| Format | qcow2 | libvirt disk format |

### Customization

Edit variables in `proxmox-pve02.pkr.hcl`:

```hcl
variable "memory" {
  default = 20480  # Change RAM (in MB)
}

variable "cpus" {
  default = 8  # Change CPU count
}

variable "disk_size" {
  default = "220G"  # Change disk size
}
```

Or pass variables during build:
```bash
packer build \
  -var 'memory=32768' \
  -var 'cpus=12' \
  -var 'disk_size=500G' \
  .
```

## Build Process

### What Happens During Build

1. **Initialization** (1 minute)
   - Download Packer plugins
   - Validate configuration

2. **ISO Boot** (2 minutes)
   - Start QEMU VM
   - Boot from unattended ISO
   - Begin Proxmox installation

3. **Installation** (20-30 minutes)
   - Install Proxmox VE
   - Configure ZFS
   - Configure networking
   - Install SSH keys

4. **Provisioning** (5 minutes)
   - Wait for Proxmox services
   - Install qemu-guest-agent
   - Install cloud-init
   - Clean up temporary files

5. **Finalization** (5 minutes)
   - Shutdown VM
   - Copy qcow2 to `templates/`
   - Create Vagrant box (libvirt) at `templates/proxmox-pve02.box`
   - Optionally upload box to HCP Vagrant Box Registry (if enabled)

### Monitoring the Build

The build runs with display enabled by default. You can:
- Connect via VNC to watch installation
- Monitor Packer output in terminal
- Check `output-proxmox-pve02/` for build artifacts

To run headless (for CI/CD):
```hcl
headless = true  # In proxmox-pve02.pkr.hcl
```

## File Structure

```
packer/
├── build.sh                    # Build orchestration script
├── proxmox-pve02.pkr.hcl       # Packer template
├── README.md                   # This file
├── output-proxmox-pve02/       # Build artifacts (temporary)
└── templates/                  # Final outputs
    ├── proxmox-pve02.qcow2     # libvirt disk (used by deploy.sh if no .box)
    └── proxmox-pve02.box       # Vagrant box (libvirt provider)
```

## Troubleshooting

### Build Fails During ISO Boot

**Problem**: VM doesn't boot from ISO or hangs

**Solution**:
```bash
# Verify ISO exists and is valid
ls -lh ../proxmox-pve02-unattended.iso

# Rebuild ISO
cd ..
./build-iso.sh

# Try again
cd packer
./build.sh
```

### SSH Timeout

**Problem**: Packer can't connect via SSH after installation

**Solution**:
- Check if Proxmox installation completed (connect via VNC)
- Verify SSH is enabled in answer file
- Check network connectivity (192.168.56.149 should respond)
- Increase `ssh_timeout` in template

### Nested Virtualization Not Working

**Problem**: KVM not available in VM

**Solution**:
```bash
# Verify host supports nested virt
egrep -c '(vmx|svm)' /proc/cpuinfo

# Check if enabled
cat /sys/module/kvm_*/parameters/nested

# Enable nested virt (Intel)
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel

# Enable nested virt (AMD)
echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf
sudo modprobe -r kvm_amd
sudo modprobe kvm_amd
```

### Out of Disk Space

**Problem**: Build fails due to insufficient disk space

**Solution**:
```bash
# Check available space
df -h

# Clean up old builds
rm -rf output-proxmox-pve02/
rm -rf templates/

# Free up space on system
# Then rebuild
```

### Slow Build Times

**Problem**: Build takes longer than expected

**Solution**:
- Use faster disk (SSD/NVMe)
- Allocate more RAM to VM
- Ensure CPU has good performance
- Check system load during build

## Advanced Usage

### Manual Packer Commands

```bash
# Initialize plugins
packer init .

# Validate template
packer validate .

# Build with custom variables
packer build \
  -var 'memory=32768' \
  -var 'cpus=12' \
  .

# Build with debug output
PACKER_LOG=1 packer build .

# Force rebuild
packer build -force .
```

### Vagrant Box Output

The Packer template includes the **Vagrant post-processor**, so each build produces a ready-to-use Vagrant box:

- **Output**: `templates/proxmox-pve02.box` (libvirt provider)
- **Also produced**: `templates/proxmox-pve02.qcow2` (for direct use or fallback)

The deploy script (`../vagrant/deploy.sh`) will use the `.box` file when present; otherwise it builds a box from the qcow2.

To add the box manually:

```bash
vagrant box add proxmox-pve02-local templates/proxmox-pve02.box --provider libvirt
```

### HCP Vagrant Box Registry (Optional)

To publish the box to [HCP Vagrant Box Registry](https://portal.cloud.hashicorp.com/vagrant/discover):

1. Create an HCP service principal and note `client_id` and `client_secret` (see [HCP IAM](https://developer.hashicorp.com/hcp/docs/hcp/admin/iam/service-principals)).
2. In `proxmox-pve02.pkr.hcl`, **uncomment** the `post-processor "vagrant-registry"` block inside the `post-processors { ... }` section.
3. Set environment variables or Packer variables:
   ```bash
   export HCP_CLIENT_ID="your-client-id"
   export HCP_CLIENT_SECRET="your-client-secret"
   packer build -var "box_tag=your-org/proxmox-pve02" -var "box_version=1.0.0" .
   ```
4. The box will be created/updated on HCP and the version released. Use `no_release = true` in the block to upload without releasing.

For **local-only builds** (no upload), leave the `vagrant-registry` block commented out (default).

### Using Template Directly with libvirt

```bash
# Copy template to libvirt images directory
sudo cp templates/proxmox-pve02.qcow2 /var/lib/libvirt/images/

# Create VM from template
virt-install \
  --name pve02-from-template \
  --memory 20480 \
  --vcpus 8 \
  --disk /var/lib/libvirt/images/proxmox-pve02.qcow2,bus=virtio \
  --network network=default \
  --graphics spice \
  --noautoconsole \
  --import
```

## CI/CD Integration

### Automated Builds

For CI/CD pipelines:

```bash
#!/bin/bash
# ci-build.sh

export PACKER_LOG=1
export PACKER_LOG_PATH=packer-build.log

# Build headless
packer build \
  -var 'headless=true' \
  -var 'iso_path=/path/to/iso' \
  .

# Check exit code
if [ $? -eq 0 ]; then
  echo "Build successful"
  # Upload template to artifact storage
else
  echo "Build failed, check logs"
  exit 1
fi
```

### Scheduled Rebuilds

To keep templates up-to-date:

```bash
# Crontab entry (weekly rebuild on Sunday at 2 AM)
0 2 * * 0 cd /path/to/homelab/environments/local/packer && ./build.sh
```

## Tips & Best Practices

1. **Keep templates fresh**: Rebuild monthly to include security updates
2. **Version templates**: Tag with date/version for tracking
3. **Test before use**: Always test new templates before using in Vagrant
4. **Clean up**: Remove old output directories after successful builds
5. **Document changes**: Keep notes on customizations in git commits

## Next Steps

After building the template:
1. Deploy with Vagrant: `cd ../vagrant && ./deploy.sh` (uses the `.box` file when present)
2. Or run the quickstart: `cd .. && ./quickstart.sh`
3. Deploy Proxmox VM and verify functionality
4. Run Ansible playbooks for additional configuration

## Support

- Packer documentation: https://www.packer.io/docs
- QEMU documentation: https://www.qemu.org/docs/master/
- Proxmox VE documentation: https://pve.proxmox.com/wiki/Main_Page
