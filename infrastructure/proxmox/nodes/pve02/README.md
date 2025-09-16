# PVE02 Unattended Installation

This directory contains the configuration files for automated installation of Proxmox VE on the second node (pve02).

> **Note**: All commands in this documentation assume you're running from the repository root directory.

## Files

- `answer.toml` - Main answer file for automated installation
- `post-install.sh` - Post-installation script for additional configuration
- `README.md` - This documentation file

## Hardware Configuration

- **OS Disk**: SanDisk SSD PLUS 240GB (ZFS RAID0, ~220GB used)
- **VM Storage**: ST1000DM010-2EP102 1TB (ZFS pool for VM datastore)
- **Network**: enp2s0 interface with DHCP

## Quick Start

### 1. Prepare ISO
```bash
cd scripts/proxmox/setup
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../../infrastructure/proxmox/nodes/pve02/answer.toml \
    --out /path/to/output/unattended-pve02.iso
```

### 2. Deploy to NanoKVM
```bash
cd scripts/proxmox/setup
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../../infrastructure/proxmox/nodes/pve02/answer.toml \
    --kvm 192.168.1.101 \
    --kvm-user root \
    --auth admin:admin \
    --smart-power \
    --send-f11
```

## Configuration Details

### Answer File (`answer.toml`)

- **Global Settings**:
  - Keyboard: US English
  - Country: US
  - FQDN: pve02.homelab.local
  - Timezone: America/New_York
  - Root password: ChangeMe123! (change this!)

- **Network**:
  - Source: DHCP
  - Interface: enp2s0

- **Disk Setup**:
  - Filesystem: ZFS
  - RAID: RAID0 (single disk)
  - Target: SanDisk SSD PLUS 240GB
  - Size: 220GB (leaving some space for over-provisioning)

### Post-Installation Script (`post-install.sh`)

The script automatically:
- Detects the ST1000DM010 disk
- Creates a ZFS pool named `vm-storage` on that disk
- Sets up appropriate datasets for VM storage
- Configures Proxmox storage

## Security Notes

⚠️ **Important**: Change the root password in the answer file before using it!

The current password is `ChangeMe123!` - this should be changed to a secure password before deployment.

## Troubleshooting

If the installation fails, check these log files:
- `/tmp/fetch_answer.log` - Answer file retrieval
- `/tmp/auto_installer` - Answer file parsing and hardware matching
- `/tmp/install-low-level-start-session.log` - Installation process
- `/var/log/pve02-post-install.log` - Post-installation script logs

## More Information

For detailed information about the installation process, script features, and additional configuration options, see the [common Proxmox documentation](../README.md).