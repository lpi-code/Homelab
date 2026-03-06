# Troubleshooting - Local Development Environment

## DNS/Network Issues with Docker

### Problem
Docker build fails with DNS timeout errors:
```
dial tcp: lookup registry-1.docker.io on 127.0.0.53:53: i/o timeout
```

### Root Cause
Docker is using systemd-resolved (127.0.0.53) which is having issues resolving Docker registry.

### Solutions

#### Solution 1: Restart systemd-resolved (Quick Fix)
```bash
sudo systemctl restart systemd-resolved
docker system prune -f
./build-iso.sh
```

#### Solution 2: Configure Docker DNS Directly
```bash
# Create or edit Docker daemon config
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
}
EOF

# Restart Docker
sudo systemctl restart docker

# Try building again
./build-iso.sh
```

#### Solution 3: Use Host Network for Docker Build
Edit `/home/lpi/git/Homelab/shared/scripts/setup-unatend-proxmox.sh` and modify the Docker run command to use host network:

```bash
# Find this line (around line 322):
$DOCKER_RUN "$workdir_abs:/work" -w /work "$DOCKER_PROXMOX_IMAGE"

# Add --network host:
$DOCKER_RUN --network host "$workdir_abs:/work" -w /work "$DOCKER_PROXMOX_IMAGE"
```

#### Solution 4: Bypass Docker Completely (Native Installation)

If Docker issues persist, install `proxmox-auto-install-assistant` natively:

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# Clone and build
git clone https://git.proxmox.com/git/pve-installer.git
cd pve-installer/proxmox-auto-installer
cargo build --release

# Install
sudo cp target/release/proxmox-auto-install-assistant /usr/local/bin/
sudo chmod +x /usr/local/bin/proxmox-auto-install-assistant

# Verify
proxmox-auto-install-assistant --version
```

Then modify `setup-unatend-proxmox.sh` to detect and use the native binary instead of Docker.

## Network Connectivity Test

```bash
# Test DNS resolution
dig registry-1.docker.io
nslookup registry-1.docker.io

# Test ping
ping -c 4 registry-1.docker.io

# Test Docker DNS
docker run --rm busybox nslookup registry-1.docker.io
```

## Alternative: Manual ISO Creation

If all else fails, you can create the ISO manually:

```bash
# 1. Download Proxmox ISO
wget https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso

# 2. Extract ISO
7z x proxmox-ve_9.1-1.iso -o/tmp/pve-iso

# 3. Add answer file
cp environments/local/proxmox/answer_pve02.toml /tmp/pve-iso/answer.toml

# 4. Rebuild ISO (requires xorriso)
cd /tmp/pve-iso
xorriso -as mkisofs \
  -o ../proxmox-pve02-unattended.iso \
  -V "PROXMOX" \
  -r -J \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  --grub2-boot-info \
  --grub2-mbr boot/grub/i386-pc/boot_hybrid.img \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  .

# 5. Move ISO to local environment
mv /tmp/proxmox-pve02-unattended.iso /home/lpi/git/Homelab/environments/local/
```

## Vagrant VM: DNS works but no internet

### Problem
The VM can resolve names (e.g. `ping google.com` works or DNS resolves) but no actual internet (e.g. `ping 8.8.8.8` fails, or `curl`/`apt` time out). This usually means the **host** is not forwarding or NATing traffic from the `homelab-local` network.

### Diagnose on the host (your Fedora/libvirt machine)

```bash
# 1. IPv4 forwarding must be 1 (if 0, the host won't forward packets)
cat /proc/sys/net/ipv4/ip_forward
# Expected: 1

# 2. Libvirt NAT rules (should show MASQUERADE for the bridge)
sudo iptables -t nat -L -n -v | head -30
# Look for chain LIBVIRT_PRT or similar and MASQUERADE for 192.168.56.0/24 / virbr-homelab

# 3. Confirm network forward mode
sudo virsh net-dumpxml homelab-local
# Should contain: <forward mode='nat'/>
```

### Diagnose inside the VM

```bash
vagrant ssh
# Or: ssh root@192.168.56.149

# Default route and gateway
ip route
# Expect: default via 192.168.56.1 dev enp0s7 (or similar)

# Can you reach the gateway?
ping -c2 192.168.56.1

# Can you reach the internet (by IP)?
ping -c2 8.8.8.8
# If this fails but DNS works, the host is not forwarding/NATing.
```

### Fix 1: Enable IPv4 forwarding on the host (required)

```bash
# Temporary
sudo sysctl -w net.ipv4.ip_forward=1

# Persistent (Fedora/RHEL)
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-libvirt-forward.conf
sudo sysctl --system
# Or: sudo sysctl -p /etc/sysctl.d/99-libvirt-forward.conf
```

### Fix 2: Restart the libvirt network (reapply NAT rules)

```bash
sudo virsh net-destroy homelab-local
sudo virsh net-start homelab-local
# If the VM is already running, it stays attached; try ping 8.8.8.8 from the VM again.
```

### Fix 3: Recreate the network with NAT (if it was created without)

If `virsh net-dumpxml homelab-local` does **not** show `<forward mode='nat'/>`:

```bash
# From environments/local/vagrant
sudo virsh net-destroy homelab-local
sudo virsh net-undefine homelab-local
./deploy.sh
# deploy.sh will recreate the network with forward mode="nat"
```

### Fix 4: Firewalld / nftables

On Fedora, firewalld can override or conflict with libvirt’s iptables rules. Try:

```bash
# See if libvirt zone is used and has masquerade
sudo firewall-cmd --list-all --zone=libvirt

# Reload and restart network
sudo firewall-cmd --reload
sudo virsh net-destroy homelab-local && sudo virsh net-start homelab-local
```

Then from the VM again: `ping -c2 8.8.8.8`.

### Fix 5: No MASQUERADE for 192.168.56.0/24 (Ubuntu + Docker)

If `ip_forward=1` but `sudo iptables -t nat -L -n -v` only shows MASQUERADE for `172.17.0.0/16` (Docker) and **nothing** for `192.168.56.0/24`, libvirt did not add the NAT rule (common on Ubuntu with Docker). Add it manually:

```bash
# One-time: MASQUERADE traffic from homelab-local so the VM can reach the internet
sudo iptables -t nat -A POSTROUTING -s 192.168.56.0/24 ! -d 192.168.56.0/24 -j MASQUERADE
```

Test from the VM: `ping -c2 8.8.8.8`. To make the rule persistent across reboots (Ubuntu):

```bash
# Install iptables-persistent if you use it
sudo apt-get install -y iptables-persistent

# Add the rule and save (Debian/Ubuntu)
sudo iptables -t nat -A POSTROUTING -s 192.168.56.0/24 ! -d 192.168.56.0/24 -j MASQUERADE
sudo netfilter-persistent save
# Or: sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

### Fix 6: FORWARD chain dropping traffic (still 100% packet loss after Fix 5)

NAT is only half of it: the **filter** table must allow forwarding. If you added MASQUERADE but ping from the VM still shows "0 received", the FORWARD chain is likely dropping packets. Check:

```bash
sudo iptables -L FORWARD -n -v
# If policy is DROP and there is no ACCEPT for 192.168.56.0/24, add:
```

On the **host** (one-time):

```bash
# Allow outbound: VM → internet
sudo iptables -I FORWARD -s 192.168.56.0/24 -j ACCEPT
# Allow return: internet → VM (established/related)
sudo iptables -I FORWARD -d 192.168.56.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

Then from the VM: `ping -c2 8.8.8.8`. To persist (Ubuntu):

```bash
sudo netfilter-persistent save
```

---

## Vagrant Issues

### VM Won't Start
```bash
# Check libvirt
sudo systemctl status libvirtd
sudo systemctl restart libvirtd

# Check nested virtualization
cat /sys/module/kvm_intel/parameters/nested

# Destroy and recreate
vagrant destroy -f
vagrant up
```

### Can't SSH to VM
```bash
# Check VM status
vagrant status
virsh list --all

# Check SSH config
vagrant ssh-config

# Manual SSH
ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.56.149
```

## ISO Build Issues

### Out of Disk Space
```bash
# Check space
df -h /tmp
df -h ~/.cache

# Clean up
rm -rf ~/.cache/nanokvm-isos/*
docker system prune -af
```

### Docker Image Build Fails
```bash
# Clean Docker
docker system prune -af
docker builder prune -af

# Rebuild manually
cd /home/lpi/git/Homelab/shared/scripts
docker build -t proxmox-auto-install-assistant:latest -f Dockerfile.proxmox .
```

## Common Errors

### "SOPS_AGE_KEY_FILE not found"
```bash
# Check if key exists
ls -la ~/.config/sops/age/keys.txt

# Generate if missing
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

### "Ansible inventory not found"
```bash
# Check path
ls -la environments/local/ansible/inventory/

# Set environment variable
export ANSIBLE_INVENTORY="$(pwd)/environments/local/ansible/inventory"
```

### "Proxmox web UI not accessible"
```bash
# Check if installation completed
vagrant ssh
systemctl status pveproxy

# Check network
ip addr show
ping 192.168.56.1

# Restart Proxmox services
systemctl restart pveproxy pvedaemon pve-cluster
```

## Getting Help

1. Check logs:
   ```bash
   vagrant ssh
   journalctl -xeu pveproxy
   journalctl -xeu pvedaemon
   ```

2. Check Vagrant logs:
   ```bash
   vagrant up --debug 2>&1 | tee vagrant-debug.log
   ```

3. Check Docker logs:
   ```bash
   docker logs <container-id>
   ```

4. Verify all prerequisites:
   ```bash
   ./quickstart.sh  # Runs prerequisite checks
   ```
