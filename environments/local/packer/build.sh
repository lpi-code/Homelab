#!/usr/bin/env bash
#
# Build Proxmox VE libvirt template using Packer
# This script orchestrates the complete build process

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ENV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ISO_PATH="$LOCAL_ENV_DIR/proxmox-pve02-unattended.iso"
BUILD_ISO_SCRIPT="$LOCAL_ENV_DIR/build-iso.sh"

info "Packer Build Script for Proxmox VE Template"
echo ""

# Check prerequisites
info "Checking prerequisites..."
MISSING_DEPS=0

if ! command -v packer &> /dev/null; then
    error "Packer is not installed"
    error "Install from: https://www.packer.io/downloads"
    MISSING_DEPS=1
else
    info "Packer is installed ($(packer version))"
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    error "QEMU is not installed"
    error "Install with: sudo dnf install qemu-kvm (Fedora) or sudo apt install qemu-system-x86 (Ubuntu)"
    MISSING_DEPS=1
else
    info "QEMU is installed"
fi

if [ ! -f "$BUILD_ISO_SCRIPT" ]; then
    error "ISO build script not found: $BUILD_ISO_SCRIPT"
    MISSING_DEPS=1
fi

if [ $MISSING_DEPS -eq 1 ]; then
    error "Missing required dependencies. Please install them and try again."
    exit 1
fi

echo ""

# Check for unattended ISO or build it
if [ ! -f "$ISO_PATH" ]; then
    info "Unattended Proxmox ISO not found, building it first..."
    echo ""
    "$BUILD_ISO_SCRIPT" || {
        error "Failed to build ISO"
        exit 1
    }
    echo ""
else
    info "Unattended ISO found: $ISO_PATH"
    info "ISO size: $(du -h "$ISO_PATH" | cut -f1)"
    echo ""
    read -p "Rebuild ISO? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Rebuilding unattended Proxmox ISO..."
        rm -f "$ISO_PATH"
        "$BUILD_ISO_SCRIPT" || {
            error "Failed to build ISO"
            exit 1
        }
        echo ""
    fi
fi

# Check nested virtualization
info "Checking nested virtualization support..."
if grep -q -E '(vmx|svm)' /proc/cpuinfo; then
    info "CPU supports virtualization"
    
    if [ -f /sys/module/kvm_intel/parameters/nested ]; then
        NESTED=$(cat /sys/module/kvm_intel/parameters/nested)
        if [ "$NESTED" = "Y" ] || [ "$NESTED" = "1" ]; then
            info "Nested virtualization is enabled (Intel)"
        else
            warn "Nested virtualization is NOT enabled (Intel)"
            warn "Enable with: echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf"
            warn "Then reboot"
        fi
    elif [ -f /sys/module/kvm_amd/parameters/nested ]; then
        NESTED=$(cat /sys/module/kvm_amd/parameters/nested)
        if [ "$NESTED" = "Y" ] || [ "$NESTED" = "1" ]; then
            info "Nested virtualization is enabled (AMD)"
        else
            warn "Nested virtualization is NOT enabled (AMD)"
            warn "Enable with: echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf"
            warn "Then reboot"
        fi
    fi
else
    error "CPU does not support virtualization extensions"
    exit 1
fi

echo ""

# Ensure libvirt network exists (needed for bridge networking)
NETWORK_NAME="homelab-local"
BRIDGE_NAME="virbr-homelab"
NETWORK_SUBNET="192.168.56.0/24"
NETWORK_GW="192.168.56.1"

info "Checking libvirt network '$NETWORK_NAME'..."
if sudo virsh net-info "$NETWORK_NAME" &>/dev/null; then
    # Check if network is active using net-list which is more reliable
    if sudo virsh net-list --name 2>/dev/null | grep -q "^${NETWORK_NAME}$"; then
        info "Network '$NETWORK_NAME' exists and is active"
    else
        info "Network '$NETWORK_NAME' exists but is inactive, starting..."
        sudo virsh net-start "$NETWORK_NAME" 2>/dev/null || info "Network already active"
        info "Network '$NETWORK_NAME' is ready"
    fi
else
    info "Creating libvirt network '$NETWORK_NAME' ($NETWORK_SUBNET)..."
    NET_XML=$(mktemp)
    cat > "$NET_XML" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <forward mode="nat"/>
  <bridge name="${BRIDGE_NAME}" stp="on" delay="0"/>
  <ip address="${NETWORK_GW}" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.56.100" end="192.168.56.200"/>
      <host mac="52:54:00:00:56:49" ip="192.168.56.149"/>
    </dhcp>
  </ip>
</network>
EOF
    sudo virsh net-define "$NET_XML"
    sudo virsh net-start "$NETWORK_NAME"
    sudo virsh net-autostart "$NETWORK_NAME"
    rm -f "$NET_XML"
    info "Network '$NETWORK_NAME' created and started"
fi

# Verify bridge exists
if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
    error "Bridge '$BRIDGE_NAME' not found. The libvirt network may not be properly configured."
    error "Try: sudo virsh net-destroy $NETWORK_NAME && sudo virsh net-start $NETWORK_NAME"
    exit 1
fi
info "Bridge '$BRIDGE_NAME' is available"

echo ""

# Initialize Packer (with sudo since build runs with sudo)
info "Initializing Packer plugins (with sudo for consistency)..."
cd "$SCRIPT_DIR"
sudo packer init . || {
    error "Failed to initialize Packer"
    exit 1
}

echo ""

# Validate Packer template
info "Validating Packer template..."
sudo packer validate . || {
    error "Packer template validation failed"
    exit 1
}

info "Packer template is valid"
echo ""

# Configure QEMU bridge helper (required for bridge networking)
BRIDGE_CONF="/etc/qemu/bridge.conf"
info "Checking QEMU bridge helper configuration..."
if [ ! -f "$BRIDGE_CONF" ] || ! grep -q "allow $BRIDGE_NAME" "$BRIDGE_CONF" 2>/dev/null; then
    info "Configuring QEMU bridge helper for '$BRIDGE_NAME'..."
    sudo mkdir -p /etc/qemu
    echo "allow $BRIDGE_NAME" | sudo tee -a "$BRIDGE_CONF" > /dev/null
    info "Added '$BRIDGE_NAME' to $BRIDGE_CONF"
fi

# Ensure qemu-bridge-helper has correct permissions
BRIDGE_HELPER="/usr/lib/qemu/qemu-bridge-helper"
if [ -f "$BRIDGE_HELPER" ]; then
    if [ ! -u "$BRIDGE_HELPER" ]; then
        info "Setting setuid on qemu-bridge-helper..."
        sudo chmod u+s "$BRIDGE_HELPER"
    fi
else
    # Try alternative location
    BRIDGE_HELPER="/usr/libexec/qemu-bridge-helper"
    if [ -f "$BRIDGE_HELPER" ] && [ ! -u "$BRIDGE_HELPER" ]; then
        info "Setting setuid on qemu-bridge-helper..."
        sudo chmod u+s "$BRIDGE_HELPER"
    fi
fi

echo ""

# Build the template
info "Starting Packer build..."
info "This will take 30-45 minutes"
info "The VM will automatically install Proxmox VE and configure it"
info ""
info "Note: Using bridge networking - Packer needs sudo for bridge access"
info "SSH will connect to: 192.168.56.149 (configured in answer file)"
echo ""

# Collect SSH public keys to inject into template (default: ~/.ssh/*.pub)
SSH_KEYS_JSON="[]"
if command -v jq &>/dev/null; then
    for f in "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/id_ed25519.pub"; do
        if [ -f "$f" ]; then
            KEY=$(cat "$f")
            SSH_KEYS_JSON=$(echo "$SSH_KEYS_JSON" | jq --arg k "$KEY" '. + [$k]')
        fi
    done
fi

# Run Packer with sudo for bridge networking access
# Enable logging to help debug any issues
sudo PACKER_LOG=1 PACKER_LOG_PATH="$SCRIPT_DIR/packer-build.log" packer build \
    -var "iso_path=$ISO_PATH" \
    -var "bridge_name=$BRIDGE_NAME" \
    -var "ssh_authorized_keys=$SSH_KEYS_JSON" \
    . || {
    error "Packer build failed"
    error "Check logs at: $SCRIPT_DIR/packer-build.log"
    error "Last 50 lines of log:"
    tail -50 "$SCRIPT_DIR/packer-build.log" 2>/dev/null || true
    exit 1
}

# Fix ownership of output files (they were created by root)
info "Fixing ownership of output files..."
sudo chown -R "$(id -u):$(id -g)" output-* templates/ 2>/dev/null || true

echo ""
info "========================================"
info "Proxmox VE Template Build Complete!"
info "========================================"
echo ""

TEMPLATE_PATH="$SCRIPT_DIR/templates/proxmox-pve02.qcow2"
BOX_PATH="$SCRIPT_DIR/templates/proxmox-pve02.box"
if [ -f "$TEMPLATE_PATH" ]; then
    info "Template location: $TEMPLATE_PATH"
    info "Template size: $(du -h "$TEMPLATE_PATH" | cut -f1)"
    [ -f "$BOX_PATH" ] && info "Vagrant box: $BOX_PATH ($(du -h "$BOX_PATH" | cut -f1))"
    echo ""
    info "Next Steps:"
    echo ""
    info "1. Deploy with Vagrant (uses .box when present):"
    info "   cd ../vagrant"
    info "   ./deploy.sh"
    echo ""
    info "2. Or run the quickstart: cd .. && ./quickstart.sh"
    echo ""
else
    error "Template not found at expected location: $TEMPLATE_PATH"
    exit 1
fi

info "========================================"
