#!/bin/bash
# Post-installation script for PVE02
# This script sets up additional ZFS pool for VM storage

set -euo pipefail

# Log file
LOG_FILE="/var/log/pve02-post-install.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "Starting PVE02 post-installation setup at $(date)"

# Function to check if disk exists and is available
check_disk() {
    local disk_path="$1"
    if [ -b "$disk_path" ]; then
        echo "Disk $disk_path found"
        return 0
    else
        echo "Disk $disk_path not found"
        return 1
    fi
}

# Function to create ZFS pool for VM storage
setup_vm_storage() {
    local disk_path="$1"
    local pool_name="vm-storage"
    
    echo "Setting up ZFS pool '$pool_name' on $disk_path"
    
    # Check if pool already exists
    if zpool list "$pool_name" >/dev/null 2>&1; then
        echo "Pool '$pool_name' already exists, skipping creation"
        return 0
    fi
    
    # Create ZFS pool
    zpool create -f \
        -o ashift=12 \
        -o compression=lz4 \
        -o checksum=on \
        -o copies=1 \
        "$pool_name" "$disk_path"
    
    # Create datasets for different VM storage types
    zfs create "$pool_name/vm-disks"
    zfs create "$pool_name/vm-templates"
    zfs create "$pool_name/iso"
    
    # Set appropriate permissions
    chown root:root "/$pool_name"
    chmod 755 "/$pool_name"
    
    echo "ZFS pool '$pool_name' created successfully"
}

# Main execution
main() {
    echo "Checking for ST1000DM010 disk..."
    
    # Look for the ST1000DM010 disk
    local vm_disk=""
    for disk in /dev/sd* /dev/nvme*; do
        if [ -b "$disk" ]; then
            # Check if this is the ST1000DM010 disk
            if hdparm -I "$disk" 2>/dev/null | grep -q "ST1000DM010"; then
                vm_disk="$disk"
                echo "Found ST1000DM010 disk at: $vm_disk"
                break
            fi
        fi
    done
    
    if [ -z "$vm_disk" ]; then
        echo "ST1000DM010 disk not found, checking by model name..."
        # Alternative method using lsblk and udev
        vm_disk=$(lsblk -d -o NAME,MODEL | grep "ST1000DM010" | awk '{print "/dev/"$1}' | head -1)
        if [ -n "$vm_disk" ]; then
            echo "Found ST1000DM010 disk at: $vm_disk"
        else
            echo "ERROR: ST1000DM010 disk not found"
            echo "Available disks:"
            lsblk -d -o NAME,MODEL,SIZE
            exit 1
        fi
    fi
    
    # Verify disk is not in use
    if mount | grep -q "$vm_disk"; then
        echo "ERROR: Disk $vm_disk is already mounted"
        exit 1
    fi
    
    # Check if disk is part of any existing ZFS pool
    if zpool status | grep -q "$vm_disk"; then
        echo "ERROR: Disk $vm_disk is already part of a ZFS pool"
        exit 1
    fi
    
    # Setup VM storage
    setup_vm_storage "$vm_disk"
    
    # Update Proxmox storage configuration
    echo "Updating Proxmox storage configuration..."
    
    # Add ZFS storage to Proxmox
    pvesm add zfspool vm-storage --pool vm-storage --content images,rootdir
    
    echo "Post-installation setup completed successfully at $(date)"
}

# Run main function
main "$@"
