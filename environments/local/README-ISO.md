# Unattended Proxmox ISO for Local Development

This environment uses an unattended Proxmox installation ISO created by the `setup-unatend-proxmox.sh` script.

## How It Works

### 1. ISO Creation

The `build-iso.sh` script uses the existing unattended Proxmox setup script **without** the `--kvm` parameter (no NanoKVM upload):

```bash
./shared/scripts/setup-unatend-proxmox.sh \
    --distro proxmox \
    --answer-file environments/local/proxmox/answer_pve02.toml \
    --out environments/local/proxmox-pve02-unattended.iso
```

This creates a Proxmox ISO with embedded automation that:
- Installs Proxmox VE completely unattended
- Configures networking from the answer file
- Sets up ZFS storage
- Adds SSH keys for passwordless access
- Sets hostname and timezone

### 2. Answer File

The answer file `proxmox/answer_pve02.toml` is configured for local libvirt networking:

```toml
[global]
fqdn = "pve02.homelab.local"
root-password = "vagrant"
root-ssh-keys = ["ssh-rsa AAAA..."]

[network]
cidr = "192.168.56.149/24"  # libvirt private network
gateway = "192.168.56.1"
dns = "192.168.56.1"

[disk-setup]
filesystem = "zfs"
disk-list = ["vda"]  # Virtual disk for libvirt
```

### 3. Vagrant Boot

The Vagrantfile attaches the ISO and boots from it:

```ruby
libvirt.storage :file,
  path: "proxmox-pve02-unattended.iso",
  device: :cdrom,
  bus: "sata"
```

## Customizing the Installation

Edit `proxmox/answer_pve02.toml` and rebuild:

```bash
# Edit answer file
vim proxmox/answer_pve02.toml

# Rebuild ISO
./build-iso.sh

# Recreate VM
vagrant destroy -f && vagrant up
```

## See Also

- [README-ISO.md](./README-ISO.md) - Detailed ISO documentation
- [Unattended Setup Documentation](../../docs/deployment/README-setup-unatend-proxmox.md)
