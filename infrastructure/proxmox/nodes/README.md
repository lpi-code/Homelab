# Proxmox VE Unattended Installation

This directory contains the configuration files for automated installation of Proxmox VE nodes.

> **Note**: All commands in this documentation assume you're running from the repository root directory.

## Node Structure

Each node directory contains:
- `answer.toml` - Main answer file for automated installation
- `post-install.sh` - Post-installation script for additional configuration
- `README.md` - Node-specific documentation

## Installation Process

### 1. Prepare the ISO

Use the existing setup script to prepare a Proxmox VE ISO with the answer file:

```bash
# Navigate to the scripts directory
cd scripts/proxmox/setup

# Prepare the ISO with the answer file
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/{NODE}/answer.toml \
    --out /path/to/output/unattended-{NODE}.iso
```

### 2. Boot and Install

1. Boot from the prepared ISO
2. The "Automated Installation" option will be selected automatically after 10 seconds
3. The installation will proceed using the configuration in `answer.toml`

### 3. Post-Installation

After the system boots for the first time, the `post-install.sh` script will:

1. Detect additional storage disks
2. Create ZFS pools for VM storage
3. Create appropriate datasets for different storage types
4. Configure Proxmox to use the new storage pools

### 4. Direct NanoKVM Deployment

If you have a NanoKVM setup, you can deploy directly:

```bash
# Deploy directly to NanoKVM
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/{NODE}/answer.toml \
    --kvm {NANOKVM_IP} \
    --kvm-user {NANOKVM_USER} \
    --auth {NANOKVM_USER}:{NANOKVM_PASS} \
    --smart-power \
    --send-f11
```

## NanoKVM Configuration Examples

### Example 1: Basic NanoKVM Deployment
```bash
# PVE01 deployment
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/pve01/answer.toml \
    --kvm 192.168.1.100 \
    --kvm-user admin \
    --auth admin:password123 \
    --smart-power \
    --send-f11
```

### Example 2: PVE02 with DHCP Network
```bash
# PVE02 deployment with DHCP (enp2s0 interface)
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/pve02/answer.toml \
    --kvm 192.168.1.101 \
    --kvm-user root \
    --auth admin:admin \
    --smart-power \
    --send-f11
```

### Example 3: PVE02 with Static IP
```bash
# PVE02 deployment with static IP configuration
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/pve02/answer.toml \
    --kvm 192.168.1.101 \
    --kvm-user root \
    --auth admin:admin \
    --iface enp2s0 \
    --ip 192.168.1.102/24 \
    --gw 192.168.1.1 \
    --dns 8.8.8.8 \
    --smart-power \
    --send-f11
```

### Example 4: PVE03 with SSH Key Authentication
```bash
# PVE03 deployment with SSH key
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/pve03/answer.toml \
    --kvm 192.168.1.102 \
    --kvm-user admin \
    --ssh-pubkey ~/.ssh/id_rsa.pub \
    --smart-power \
    --send-f11
```

## Script Features

The `setup-unatend-proxmox.sh` script provides additional features:

- **Automatic ISO Download**: Downloads the latest Proxmox VE ISO automatically
- **Docker Support**: Uses Docker for cross-platform compatibility (including macOS)
- **NanoKVM Integration**: Direct deployment to NanoKVM devices with power management
- **Smart Power Management**: Automatically handles power states during deployment
- **F11 Key Simulation**: Automatically selects boot device in BIOS/UEFI
- **Answer File Validation**: Built-in validation of TOML answer files
- **Caching**: Caches downloaded ISOs to avoid re-downloading
- **SSH Key Support**: Supports both password and SSH key authentication

## Configuration Details

### Answer File (`answer.toml`)

Each node's answer file contains:
- **Global Settings**: Keyboard, country, FQDN, timezone, root password
- **Network**: Interface selection and configuration (DHCP or static)
- **Disk Setup**: Filesystem type, RAID configuration, disk selection
- **Post-Installation**: Webhook configuration and first-boot hooks

### Post-Installation Script (`post-install.sh`)

The script automatically:
- Detects additional storage disks
- Creates ZFS pools for VM storage
- Sets up appropriate datasets
- Configures Proxmox storage

## Troubleshooting

If the installation fails, check these log files:
- `/tmp/fetch_answer.log` - Answer file retrieval
- `/tmp/auto_installer` - Answer file parsing and hardware matching
- `/tmp/install-low-level-start-session.log` - Installation process
- `/var/log/{NODE}-post-install.log` - Post-installation script logs

## Validation

The setup script automatically validates the answer file when using the `--answer-file` parameter. You can also validate manually by running the script in dry-run mode:

```bash
# The script will validate the answer file automatically when using --answer-file
./setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file ../../infrastructure/proxmox/nodes/{NODE}/answer.toml \
    --out /tmp/test-validation.iso
```

## Security Notes

⚠️ **Important**: Change the root password in each node's answer file before using it!

The default passwords should be changed to secure passwords before deployment.

## Network Configuration

Most nodes are configured to use DHCP. Ensure your DHCP server provides:
- IP address
- Gateway
- DNS servers
- Hostname (optional, will use the configured FQDN if not provided)

For static IP configurations, the answer file will contain the network settings directly.
