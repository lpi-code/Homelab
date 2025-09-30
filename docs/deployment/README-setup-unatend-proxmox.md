# NanoKVM Unattended Proxmox Setup Script

## Overview

The `setup-unatend-proxmox.sh` script is a comprehensive automation tool that creates unattended installation ISOs for Proxmox VE and automatically deploys them to NanoKVM devices. It supports both Debian-based installations (recommended) and direct Proxmox VE ISO modifications.

## Features

- **Automated ISO Creation**: Downloads latest Debian or Proxmox VE ISOs and makes them fully unattended
- **Intelligent Caching**: Caches downloaded ISOs to avoid re-downloading on subsequent runs
- **Smart Upload Detection**: Checks if ISO already exists on NanoKVM before building, asks for confirmation to overwrite
- **Network Configuration**: Supports static IP configuration with automatic netmask calculation
- **SSH Key Authentication**: Automatically configures SSH key-based authentication
- **Proxmox VE Installation**: Installs Proxmox VE during the Debian installation process
- **NanoKVM Integration**: Uploads ISOs and controls ATX power management via HTTP API
- **Boot Flag Preservation**: Maintains original ISO boot capabilities when rebuilding
- **Checksum Verification**: Optional SHA256 checksum validation for downloaded ISOs
- **Cache Management**: Automatic cleanup of old cached files

## Prerequisites

### Required Tools
- `curl` - For downloading ISOs and API communication
- `ssh` - For NanoKVM connectivity
- `rsync` - For file uploads with progress bar
- `7z` - For ISO extraction
- `xorriso` (preferred) or `genisoimage` + `isohybrid` - For ISO creation
- `python3` - For netmask calculation
- `jq` - For JSON processing and URL encoding
- `openssl` - For password encryption

### System Requirements
- Linux system with bash 5.1+
- Sufficient disk space for ISO downloads and temporary files
- Network connectivity to download ISOs and access NanoKVM

## Usage

### Basic Syntax
```bash
./setup-unatend-proxmox.sh [OPTIONS]
```

### Command Line Options

#### Distribution Selection
- `--distro {debian|proxmox}` - Choose installation type (default: debian)
  - `debian`: Downloads Debian netinst and installs Proxmox VE via late_command (recommended)
  - `proxmox`: Downloads Proxmox VE ISO directly (experimental)

#### Output Configuration
- `--out ISO_PATH` - Specify custom output ISO path (default: auto-generated)

#### System Configuration
- `--hostname FQDN` - Set system hostname (default: pve)
- `--timezone TZ` - Set timezone (default: UTC)

#### Network Configuration
- `--iface INTERFACE` - Network interface name (e.g., eno1, eth0)
- `--ip IP/CIDR` - Static IP address with CIDR notation (e.g., 192.0.2.10/24)
- `--gw GATEWAY` - Gateway IP address
- `--dns DNS_SERVER` - DNS server IP (default: 1.1.1.1)

#### Authentication
- `--ssh-pubkey PATH` - SSH public key path (default: ~/.ssh/id_rsa.pub)
- `--root-pass PASSWORD` - Root password (if empty, root locked, SSH key only)

#### Disk Selection
- `--disk-model MODEL` - Target disk by model name (e.g., "Samsung SSD 980 PRO")
- `--disk-serial SERIAL` - Target disk by serial number (e.g., "S5GXNX0N123456")
- `--disk-path PATH` - Target disk by device path (e.g., "/dev/sda", "/dev/nvme0n1")
- `--disk-size SIZE` - Target disk by minimum size (e.g., "500G", "1T")

#### NanoKVM Configuration
- `--kvm HOST` - NanoKVM hostname or IP address (required for upload)
- `--kvm-user USER` - SSH username for NanoKVM (default: root)
- `--kvm-port PORT` - SSH port for NanoKVM (default: 22)
- `--auth USER:PASS` - HTTP API authentication for NanoKVM control

#### NanoKVM Actions
- `--select` - Automatically select uploaded ISO
- `--poweron` - Power on the system after upload (default: enabled)
- `--poweroff` - Power off the system
- `--reset` - Reset/reboot the system

#### Advanced Options
- `--https` - Use HTTPS for NanoKVM API calls
- `--curl-extra "OPTIONS"` - Additional curl options for API calls
- `--cache-dir DIR` - Custom cache directory (default: ~/.cache/nanokvm-isos)
- `--cache-age DAYS` - Cache ISOs for specified days (default: 7)
- `--force-download` - Force re-download even if cached ISO exists
- `--quiet` - Suppress progress messages

## Examples

### Complete Debian + Proxmox Setup
```bash
./setup-unatend-proxmox.sh \
  --distro debian \
  --kvm 10.0.0.50 \
  --auth admin:password \
  --select --reset \
  --hostname pve01.example.com \
  --timezone "America/New_York" \
  --iface eno1 \
  --ip 192.168.1.100/24 \
  --gw 192.168.1.1 \
  --dns 8.8.8.8 \
  --ssh-pubkey ~/.ssh/id_ed25519.pub
```
*Note: The system will automatically power on after upload by default.*

### Proxmox VE Direct Installation
```bash
./setup-unatend-proxmox.sh \
  --distro proxmox \
  --kvm 10.0.0.50 \
  --auth admin:password \
  --select
```
*Note: The system will automatically power on after upload by default.*

### Local ISO Creation Only
```bash
./setup-unatend-proxmox.sh \
  --distro debian \
  --hostname pve01 \
  --iface eth0 \
  --ip 192.168.1.100/24 \
  --gw 192.168.1.1 \
  --out /path/to/custom-proxmox.iso
```

### With Custom Cache Settings
```bash
./setup-unatend-proxmox.sh \
  --distro debian \
  --cache-dir /tmp/my-cache \
  --cache-age 3 \
  --kvm 10.0.0.50
```

### Force Re-download (Ignore Cache)
```bash
./setup-unatend-proxmox.sh \
  --distro debian \
  --force-download \
  --kvm 10.0.0.50
```

### With Disk Selection
```bash
# Select disk by model
./setup-unatend-proxmox.sh \
  --distro debian \
  --disk-model "Samsung SSD 980 PRO" \
  --kvm 10.0.0.50

# Select disk by size
./setup-unatend-proxmox.sh \
  --distro debian \
  --disk-size "1T" \
  --kvm 10.0.0.50

# Select specific disk path
./setup-unatend-proxmox.sh \
  --distro debian \
  --disk-path "/dev/nvme0n1" \
  --kvm 10.0.0.50
```

## How It Works

### Debian Installation Process
1. **ISO Download**: Fetches latest Debian netinst ISO from official mirrors
2. **Checksum Verification**: Validates ISO integrity using SHA256 checksums
3. **ISO Extraction**: Extracts ISO contents using 7z
4. **Preseed Generation**: Creates comprehensive preseed configuration including:
   - Network configuration (static or DHCP)
   - User authentication (SSH keys and/or password)
   - Package selection (SSH, sudo, curl, etc.)
   - Partitioning (atomic recipe for full disk)
5. **Proxmox Installation**: Adds late_command to install Proxmox VE:
   - Configures Proxmox repositories
   - Installs proxmox-ve, postfix, and open-iscsi
   - Enables required services
6. **Boot Configuration**: Modifies boot menus to use preseed file
7. **ISO Rebuild**: Creates new ISO preserving original boot flags

### Proxmox VE Installation Process
1. **ISO Discovery**: Scrapes Proxmox website for latest ISO download link
2. **ISO Download**: Downloads Proxmox VE ISO directly
3. **Preseed Creation**: Creates basic preseed for unattended installation
4. **Boot Modification**: Updates boot configuration for preseed usage
5. **ISO Rebuild**: Rebuilds ISO with unattended configuration

### NanoKVM Integration
1. **Smart Upload Detection**: Checks if ISO already exists on NanoKVM before building
2. **ISO Upload**: Uploads generated ISO to NanoKVM `/data` directory via rsync with progress bar
3. **API Authentication**: Logs into NanoKVM HTTP API using `/api/auth/login` endpoint
4. **Status Monitoring**: Checks LED status and device information via API
5. **ISO Mounting**: Automatically mounts uploaded ISO for boot using storage API
6. **Power Management**: Controls ATX power via GPIO API (`/api/vm/gpio`)

## Disk Selection Guide

### Finding Disk Information

Before using disk selection options, you need to identify the target disk. Here are several methods:

#### Method 1: Using `lsblk` (Recommended)
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE
```
Example output:
```
NAME        SIZE MODEL              SERIAL      TYPE
sda       465.8G Samsung SSD 980 PRO S5GXNX0N123456 disk
├─sda1      512M                    part
└─sda2    465.3G                    part
nvme0n1   1.8T Samsung SSD 980 PRO 1TB S5GXNX0N789012 disk
```

#### Method 2: Using `lshw`
```bash
sudo lshw -class disk -short
```

#### Method 3: Using `fdisk`
```bash
sudo fdisk -l
```

#### Method 4: Check `/sys/block/` directly
```bash
# List all block devices
ls /sys/block/

# Get model for specific device
cat /sys/block/sda/device/model

# Get serial for specific device  
cat /sys/block/sda/device/serial

# Get size in sectors
cat /sys/block/sda/size
```

### Disk Selection Options

The script supports multiple ways to identify the target disk:

1. **By Model Name** (`--disk-model`): Most reliable for specific drives
   ```bash
   --disk-model "Samsung SSD 980 PRO"
   ```

2. **By Serial Number** (`--disk-serial`): Most unique identifier
   ```bash
   --disk-serial "S5GXNX0N123456"
   ```

3. **By Device Path** (`--disk-path`): Direct device specification
   ```bash
   --disk-path "/dev/sda"
   --disk-path "/dev/nvme0n1"
   ```

4. **By Minimum Size** (`--disk-size`): Size-based selection
   ```bash
   --disk-size "500G"    # 500 GB minimum
   --disk-size "1T"      # 1 TB minimum
   --disk-size "2T"      # 2 TB minimum
   ```

### Disk Selection Logic

The script uses the following priority order:
1. If `--disk-path` is specified, use it directly
2. Otherwise, scan all available disks and match by:
   - Model name (if `--disk-model` specified)
   - Serial number (if `--disk-serial` specified)  
   - Minimum size (if `--disk-size` specified)
3. If no criteria match, fall back to `/dev/sda`

### Safety Considerations

- **Always verify disk selection** before running on production systems
- **Use serial numbers** for the most reliable identification
- **Test with `--disk-path`** first to ensure correct disk selection
- **Backup important data** before unattended installation

## Configuration Details

### Preseed Configuration
The script generates comprehensive preseed files that configure:

- **Localization**: English US locale, US keyboard layout
- **Timezone**: Configurable timezone setting
- **Network**: Static IP or DHCP configuration
- **Authentication**: SSH key and/or password authentication
- **Partitioning**: Atomic partitioning (full disk usage)
- **Packages**: Essential packages for Proxmox VE
- **Services**: Automatic service configuration

### Network Configuration
- Supports both static IP and DHCP configurations
- Automatic netmask calculation from CIDR notation
- Configurable gateway and DNS settings
- Interface selection (auto or specific interface)

### Security Features
- SSH key-based authentication (recommended)
- Optional root password (can be disabled for key-only access)
- Secure file permissions for SSH keys
- Non-interactive installation for security

## NanoKVM API Reference

The script uses the following NanoKVM API endpoints based on the [official documentation](https://github.com/sipeed/NanoKVM/issues/90):

### Authentication
- `POST /api/auth/login` - Login with encrypted password authentication
  - Password is encrypted using AES-256-CBC with key "nanokvm-sipeed-2024"
  - Returns token in response data with `{"code":0,"msg":"success","data":{"token":"..."}}`
  - Token is used as cookie for subsequent requests
  - All API responses must have `code: 0` to indicate success

### Status Monitoring
- `GET /api/vm/info` - Get device information (IP, firmware, current image)
- `GET /api/vm/gpio/led` - Get LED status (power/HDD indicators)
- `GET /api/storage/images/mounted` - Get currently mounted image

### Power Control
- `POST /api/vm/gpio` - Control GPIO (power button press)
  - Body: `{"type":"power","duration":800}`

### Storage Management
- `POST /api/storage/images/mount` - Mount ISO image
  - Body: `{"name":"filename.iso"}`

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```bash
   # Install required packages
   sudo apt-get install curl ssh-client p7zip-full xorriso python3
   # or
   sudo yum install curl openssh-clients p7zip xorriso python3
   ```

2. **ISO Creation Fails**
   - Ensure sufficient disk space in `/tmp` or `$TMPDIR`
   - Check that xorriso or genisoimage+isohybrid are installed
   - Verify ISO download completed successfully

3. **NanoKVM Upload Fails**
   - Verify SSH connectivity: `ssh -p 22 root@NANO_KVM_IP`
   - Check NanoKVM has sufficient storage space
   - Ensure `/data` directory is writable
   - Verify rsync is installed on both local and remote systems

4. **API Authentication Fails**
   - Verify NanoKVM HTTP API is enabled
   - Check authentication credentials format: `admin:password`
   - Ensure `jq` and `openssl` are installed for proper authentication
   - The script uses AES-256-CBC encryption with key "nanokvm-sipeed-2024"
   - Check if the NanoKVM firmware version supports the API endpoints

5. **Network Configuration Issues**
   - Verify IP address and gateway are on same subnet
   - Check DNS server accessibility
   - Ensure interface name matches system configuration

### Debug Mode
Run with `--quiet` disabled to see detailed progress messages and identify issues.

### Log Files
The script uses temporary directories for processing. Check `/tmp/nanokvm-auto-*` for intermediate files if debugging is needed.

## Security Considerations

- **SSH Keys**: Use strong SSH keys (ed25519 recommended)
- **Root Password**: Consider disabling root password for key-only access
- **Network Security**: Use secure networks for initial deployment
- **API Credentials**: Use strong passwords for NanoKVM API access
- **ISO Verification**: Always verify checksums when possible

## Advanced Usage

### Custom Mirrors
Modify the `MIRROR_HTTP` variable in the script to use custom Debian mirrors.

### Custom Preseed
The script generates preseed files dynamically. For advanced customization, modify the preseed generation sections in the script.

### Multiple Deployments
The script can be run multiple times with different configurations to create multiple ISOs for different systems.

## License

This script is provided as-is for educational and automation purposes. Please ensure compliance with Debian and Proxmox VE licensing terms when using this tool.

## Support

For issues related to:
- **Debian Installation**: Check Debian preseed documentation
- **Proxmox VE**: Refer to Proxmox VE installation documentation
- **NanoKVM**: Consult NanoKVM device documentation
- **Script Issues**: Review script output and check prerequisites

