#!/usr/bin/env bash
#
# Deploy Proxmox VE from Packer Template using Vagrant
# This script automates the deployment of the VM from the template

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is not installed"
        return 1
    fi
    info "$1 is installed"
    return 0
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ENV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKER_DIR="$LOCAL_ENV_DIR/packer"
TEMPLATE_PATH="$PACKER_DIR/templates/proxmox-pve02.qcow2"
BOX_PATH="$PACKER_DIR/templates/proxmox-pve02.box"
BOX_NAME="proxmox-pve02-local"

# Script start
info "Vagrant Deployment Script for Proxmox VE"
echo ""

# Check prerequisites
info "Checking prerequisites..."
echo ""

MISSING_DEPS=0

if ! check_command vagrant; then
    error "Please install Vagrant: https://www.vagrantup.com/downloads"
    MISSING_DEPS=1
fi

if ! check_command virsh; then
    error "Please install libvirt/KVM"
    MISSING_DEPS=1
fi

if ! vagrant plugin list | grep -q vagrant-libvirt; then
    error "Please install vagrant-libvirt plugin: vagrant plugin install vagrant-libvirt"
    MISSING_DEPS=1
else
    info "vagrant-libvirt plugin is installed"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    error "Missing required dependencies. Please install them and try again."
    exit 1
fi

echo ""
info "All prerequisites satisfied!"
echo ""

# Check nested virtualization
info "Checking nested virtualization support..."
if grep -q -E '(vmx|svm)' /proc/cpuinfo; then
    info "CPU supports virtualization"

    # Check if nested is enabled
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

# Ensure libvirt network exists
NETWORK_NAME="homelab-local"
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
  <bridge name="virbr-homelab" stp="on" delay="0"/>
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

echo ""

# Prefer Packer-built Vagrant .box when present; otherwise require qcow2 template
if [ -f "$BOX_PATH" ]; then
    USE_BOX_FILE=1
    info "Vagrant box file found: $BOX_PATH"
    info "Box size: $(du -h "$BOX_PATH" | cut -f1)"
elif [ -f "$TEMPLATE_PATH" ]; then
    USE_BOX_FILE=0
    info "Packer template (qcow2) found: $TEMPLATE_PATH"
    info "Template size: $(du -h "$TEMPLATE_PATH" | cut -f1)"
else
    error "No box or template found. Build with Packer first:"
    info "  cd $PACKER_DIR"
    info "  ./build.sh"
    echo ""
    exit 1
fi
echo ""

# Check if Vagrant box already exists
if vagrant box list | grep -q "$BOX_NAME"; then
    info "Vagrant box '$BOX_NAME' is already added"
    read -p "Remove and re-add from template/box? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Removing existing box..."
        vagrant box remove "$BOX_NAME" --provider libvirt --force
        if [ "$USE_BOX_FILE" = 1 ]; then
            info "Re-adding box from Packer .box file..."
            vagrant box add "$BOX_NAME" "$BOX_PATH" --provider libvirt
        else
            info "Re-adding box from qcow2 template..."
            BOX_DIR=$(mktemp -d)
            cp "$TEMPLATE_PATH" "$BOX_DIR/box.img"
            cat > "$BOX_DIR/metadata.json" <<EOF
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": 220
}
EOF
            cat > "$BOX_DIR/Vagrantfile" <<'EOF'
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.memory = 20480
    libvirt.cpus = 8
  end
end
EOF
            tar czf "$BOX_DIR/$BOX_NAME.box" -C "$BOX_DIR" metadata.json Vagrantfile box.img
            vagrant box add "$BOX_NAME" "$BOX_DIR/$BOX_NAME.box" --provider libvirt
            rm -rf "$BOX_DIR"
        fi
        info "Box re-added successfully"
    fi
else
    if [ "$USE_BOX_FILE" = 1 ]; then
        info "Adding Vagrant box from Packer .box file..."
        vagrant box add "$BOX_NAME" "$BOX_PATH" --provider libvirt
    else
        info "Adding Packer template as Vagrant box (from qcow2)..."
        BOX_DIR=$(mktemp -d)
        cp "$TEMPLATE_PATH" "$BOX_DIR/box.img"
        cat > "$BOX_DIR/metadata.json" <<EOF
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": 220
}
EOF
        cat > "$BOX_DIR/Vagrantfile" <<'EOF'
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.memory = 20480
    libvirt.cpus = 8
  end
end
EOF
        tar czf "$BOX_DIR/$BOX_NAME.box" -C "$BOX_DIR" metadata.json Vagrantfile box.img
        vagrant box add "$BOX_NAME" "$BOX_DIR/$BOX_NAME.box" --provider libvirt
        rm -rf "$BOX_DIR"
    fi
    info "Box added successfully"
fi

echo ""

# Change to Vagrant directory
cd "$SCRIPT_DIR"

# Detect user's SSH key and inject for Vagrant (must match keys used in Packer build)
for key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
    if [ -f "$key" ]; then
        export VAGRANT_SSH_PRIVATE_KEY="$key"
        info "Using SSH key: $key"
        break
    fi
done
if [ -z "${VAGRANT_SSH_PRIVATE_KEY:-}" ]; then
    warn "No SSH key found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa); Vagrant will use password auth"
fi
echo ""

# Check if Vagrant VM already exists
if vagrant status | grep -q "running"; then
    info "Vagrant VM is already running"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Destroying existing VM..."
        vagrant destroy -f
    else
        info "Keeping existing VM. Run 'vagrant reload --provision' to re-provision."
        exit 0
    fi
elif vagrant status | grep -q "saved\|poweroff"; then
    info "Vagrant VM exists but is stopped"
    read -p "Start existing VM or recreate? (s=start/r=recreate/N=exit): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        info "Starting existing VM..."
        vagrant up
        exit 0
    elif [[ $REPLY =~ ^[Rr]$ ]]; then
        info "Destroying and recreating VM..."
        vagrant destroy -f
    else
        exit 0
    fi
fi

echo ""
info "Starting Vagrant VM from template..."
info "This should be much faster than building from ISO (5-10 minutes)"
echo ""

# Start Vagrant
vagrant up

echo ""
info "Vagrant deployment complete!"
echo ""

# Display access information
info "========================================"
info "Proxmox VE Local Environment Ready!"
info "========================================"
echo ""
info "Access Information:"
info "  Web Interface: https://192.168.56.149:8006"
info "  Username: root"
info "  Password: vagrantvagrant (change this!)"
echo ""
info "SSH Access:"
info "  vagrant ssh"
echo ""
info "Next Steps:"
echo ""
info "1. Change root password:"
info "   vagrant ssh"
info "   sudo passwd root"
echo ""
info "2. Create/update SOPS secrets file:"
info "   sops $LOCAL_ENV_DIR/ansible/host_vars/pve02/99-secrets.sops.yaml"
echo ""
info "3. Run Ansible playbooks:"
info "   cd $LOCAL_ENV_DIR/.."
info "   export ANSIBLE_ENVIRONMENT=local"
info "   ansible-playbook -i environments/local/ansible/inventory \\"
info "     shared/ansible/playbooks/00-post-install-pve.yml --limit pve02"
echo ""
info "========================================"
echo ""
info "For more information, see $SCRIPT_DIR/README.md"
