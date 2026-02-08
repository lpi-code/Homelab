#!/usr/bin/env bash
#
# Quick Start Script for Local Development Environment
# This script guides you through the Packer + Vagrant workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

highlight() {
    echo -e "${BLUE}[WORKFLOW]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script start
echo ""
echo "=========================================="
info "Homelab Local Environment Quick Start"
echo "=========================================="
echo ""

highlight "The local environment now uses a Packer + Vagrant workflow:"
echo ""
echo "  1. PACKER:  Build a reusable Proxmox VM template (once)"
echo "  2. VAGRANT: Deploy the template quickly (repeatedly)"
echo ""
echo "This separation allows you to:"
echo "  - Build the template once (~30-45 min)"
echo "  - Deploy VMs quickly from template (~5-10 min)"
echo "  - Rebuild template when base system changes"
echo ""
echo "=========================================="
echo ""

# Check what already exists (Packer produces .qcow2 and optionally .box)
TEMPLATE_EXISTS=false
if [ -f "$SCRIPT_DIR/packer/templates/proxmox-pve02.qcow2" ] || [ -f "$SCRIPT_DIR/packer/templates/proxmox-pve02.box" ]; then
    TEMPLATE_EXISTS=true
fi

if [ "$TEMPLATE_EXISTS" = true ]; then
    info "✓ Packer template/box already exists"
    echo ""
    echo "Options:"
    echo "  1) Deploy VM from existing template (FAST - recommended)"
    echo "  2) Rebuild template then deploy (SLOW)"
    echo "  3) Just rebuild template"
    echo "  4) Exit"
    echo ""
    read -p "Choose option [1-4]: " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            info "Deploying from existing template..."
            cd "$SCRIPT_DIR/vagrant"
            ./deploy.sh
            ;;
        2)
            info "Rebuilding template first..."
            cd "$SCRIPT_DIR/packer"
            ./build.sh
            
            info "Now deploying..."
            cd "$SCRIPT_DIR/vagrant"
            ./deploy.sh
            ;;
        3)
            info "Rebuilding template only..."
            cd "$SCRIPT_DIR/packer"
            ./build.sh
            ;;
        4)
            info "Exiting"
            exit 0
            ;;
        *)
            error "Invalid option"
            exit 1
            ;;
    esac
else
    warn "Packer template/box not found"
    echo ""
    info "You need to build the template first (this is a one-time operation; produces .qcow2 and .box)"
    echo ""
    echo "Options:"
    echo "  1) Build template then deploy (recommended for first time)"
    echo "  2) Just build template"
    echo "  3) Exit"
    echo ""
    read -p "Choose option [1-3]: " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            info "Building template..."
            cd "$SCRIPT_DIR/packer"
            ./build.sh
            
            info "Now deploying..."
            cd "$SCRIPT_DIR/vagrant"
            ./deploy.sh
            ;;
        2)
            info "Building template only..."
            cd "$SCRIPT_DIR/packer"
            ./build.sh
            ;;
        3)
            info "Exiting"
            exit 0
            ;;
        *)
            error "Invalid option"
            exit 1
            ;;
    esac
fi

echo ""
echo "=========================================="
info "Quick Start Complete!"
echo "=========================================="
echo ""
info "For more details:"
info "  - Packer workflow: $SCRIPT_DIR/packer/README.md"
info "  - Vagrant workflow: $SCRIPT_DIR/vagrant/README.md"
info "  - Full documentation: $SCRIPT_DIR/README.md"
echo ""
