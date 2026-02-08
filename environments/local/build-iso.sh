#!/usr/bin/env bash
#
# Build Unattended Proxmox ISO for Local Development
# Uses the existing setup-unatend-proxmox.sh script without NanoKVM upload

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
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSWER_FILE="$SCRIPT_DIR/proxmox/answer_pve02.toml"
OUTPUT_ISO="$SCRIPT_DIR/proxmox-pve02-unattended.iso"
SETUP_SCRIPT="$REPO_ROOT/shared/scripts/setup-unatend-proxmox.sh"

info "Building unattended Proxmox ISO for local development"
echo ""

# Check if answer file exists
if [ ! -f "$ANSWER_FILE" ]; then
    error "Answer file not found: $ANSWER_FILE"
    exit 1
fi

# Check if setup script exists
if [ ! -f "$SETUP_SCRIPT" ]; then
    error "Setup script not found: $SETUP_SCRIPT"
    exit 1
fi

# Check prerequisites
info "Checking prerequisites..."
for cmd in curl docker; do
    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is not installed"
        exit 1
    fi
done

# Check if Docker is running
if ! docker info &> /dev/null; then
    error "Docker is not running. Please start Docker first."
    exit 1
fi

info "Prerequisites satisfied"
echo ""

# Build the ISO using the existing script
# NOTE: No --kvm parameter means it will only build locally without uploading
info "Building unattended Proxmox ISO..."
info "Answer file: $ANSWER_FILE"
info "Output ISO: $OUTPUT_ISO"
echo ""

"$SETUP_SCRIPT" \
    --distro proxmox \
    --answer-file "$ANSWER_FILE" \
    --out "$OUTPUT_ISO"

if [ -f "$OUTPUT_ISO" ]; then
    info "✅ ISO built successfully: $OUTPUT_ISO"
    info "ISO size: $(du -h "$OUTPUT_ISO" | cut -f1)"
    echo ""
    info "Next steps:"
    info "  1. Use this ISO with Vagrant: vagrant up"
    info "  2. Or manually boot with virt-install:"
    info "     virt-install --name pve02-local --ram 32768 --vcpus 8 \\"
    info "       --disk size=220 --cdrom $OUTPUT_ISO --network network=default"
else
    error "Failed to build ISO"
    exit 1
fi
