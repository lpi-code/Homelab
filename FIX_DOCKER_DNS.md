# Fix Docker Desktop DNS Issues

## Problem
Docker Desktop can't resolve DNS, causing timeouts when pulling images:
```
dial tcp: lookup registry-1.docker.io on 127.0.0.53:53: i/o timeout
```

## Root Cause
Docker Desktop is using the host's systemd-resolved DNS (127.0.0.53) which is experiencing timeouts.

## Solutions (Try in Order)

### Solution 1: Restart Docker Desktop & DNS (Quickest)

```bash
# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Quit Docker Desktop completely
docker context use default  # Switch away from desktop
pkill -f "Docker Desktop"

# Start Docker Desktop again from applications menu
# Or: nohup /usr/bin/docker-desktop &

# Wait 30 seconds, then test
docker run --rm hello-world
```

### Solution 2: Configure Docker Desktop DNS (Recommended)

Open Docker Desktop settings and configure DNS:

```bash
# Stop Docker Desktop first
pkill -f "Docker Desktop"

# Edit Docker Desktop daemon config
mkdir -p ~/.docker/desktop
cat > ~/.docker/desktop/daemon.json <<'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "dns-search": [],
  "dns-opts": []
}
EOF

# Restart Docker Desktop
nohup /usr/bin/docker-desktop &
```

### Solution 3: Use Host DNS Directly

```bash
# Get your actual DNS servers (not systemd-resolved)
resolvectl status | grep "DNS Servers"

# Example output: DNS Servers: 62.201.129.202

# Configure Docker Desktop to use those
cat > ~/.docker/desktop/daemon.json <<'EOF'
{
  "dns": ["62.201.129.202", "62.201.129.201", "8.8.8.8"]
}
EOF

# Restart Docker Desktop
```

### Solution 4: Fix systemd-resolved Configuration

```bash
# Create resolved configuration
sudo mkdir -p /etc/systemd/resolved.conf.d

sudo tee /etc/systemd/resolved.conf.d/dns.conf <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=62.201.129.202 62.201.129.201
DNSStubListener=yes
EOF

# Restart systemd-resolved
sudo systemctl restart systemd-resolved

# Verify it works
resolvectl status
dig registry-1.docker.io

# Restart Docker Desktop
pkill -f "Docker Desktop"
nohup /usr/bin/docker-desktop &
```

### Solution 5: Use Docker Desktop GUI

1. Open **Docker Desktop**
2. Click **Settings** (⚙️ icon)
3. Go to **Resources** → **Network**
4. Look for **DNS Server** settings
5. Change from "Automatic" to "Manual"
6. Add: `8.8.8.8, 1.1.1.1`
7. Click **Apply & Restart**

### Solution 6: Switch to Native Docker (Alternative)

If Docker Desktop continues to have issues, switch to native Docker:

```bash
# Uninstall Docker Desktop
sudo dnf remove docker-desktop  # or your package manager

# Install native Docker
sudo dnf install docker docker-compose-plugin

# Enable and start
sudo systemctl enable --now docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Configure DNS
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "dns-search": []
}
EOF

sudo systemctl restart docker

# Test
docker run --rm hello-world
```

## Testing DNS Resolution

After applying any fix, test:

```bash
# Test 1: Basic connectivity
ping -c 2 8.8.8.8

# Test 2: DNS resolution from host
dig registry-1.docker.io
nslookup registry-1.docker.io

# Test 3: Docker DNS
docker run --rm alpine nslookup registry-1.docker.io

# Test 4: Pull an image
docker pull alpine:latest

# Test 5: Build something
docker build -t test -<<'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
EOF
```

## Quick Diagnostic Commands

```bash
# Check Docker context
docker context ls

# Check Docker Desktop status
ps aux | grep docker-desktop

# Check DNS being used
docker run --rm alpine cat /etc/resolv.conf

# Check host DNS
cat /etc/resolv.conf
resolvectl status

# Check systemd-resolved
systemctl status systemd-resolved
journalctl -u systemd-resolved -n 50
```

## Common Issues

### Issue: "Cannot connect to Docker daemon"
```bash
# Check Docker Desktop is running
docker context use desktop-linux
docker info
```

### Issue: Still getting DNS timeouts
```bash
# Completely reset Docker Desktop
rm -rf ~/.docker/desktop
rm -rf ~/.docker/run

# Reinstall/restart Docker Desktop
```

### Issue: Intermittent DNS failures
```bash
# Increase DNS timeout
cat > ~/.docker/desktop/daemon.json <<'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"],
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
EOF
```

## For Immediate ISO Build

If you need to build the ISO **right now** and can't wait for Docker fixes:

### Option A: Use Cached Images

```bash
# Pull images on a working machine, save them
docker pull debian:bookworm-slim
docker pull rust:1.75-bookworm
docker save -o /tmp/docker-images.tar debian:bookworm-slim rust:1.75-bookworm

# Transfer to your machine
# Load them
docker load -i /tmp/docker-images.tar

# Now build should work
./build-iso.sh
```

### Option B: Use Pre-built ISO

Download a pre-built Proxmox ISO and configure it manually:

```bash
# Download official Proxmox ISO
wget https://enterprise.proxmox.com/iso/proxmox-ve_9.1-1.iso \
  -O environments/local/proxmox-pve02-unattended.iso

# Use it directly with Vagrant (note: not unattended, manual install)
vagrant up

# Then configure manually through web UI
```

### Option C: Build on Different Machine

If you have another machine with working Docker:

```bash
# On working machine
cd /home/lpi/git/Homelab/environments/local
./build-iso.sh

# Transfer ISO to your machine
scp proxmox-pve02-unattended.iso your-machine:/home/lpi/git/Homelab/environments/local/

# Then vagrant up
```

## Recommended Solution for You

Based on your setup (Docker Desktop on Fedora with systemd-resolved), I recommend:

```bash
# 1. Fix systemd-resolved
sudo tee /etc/systemd/resolved.conf.d/dns.conf <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=62.201.129.202 62.201.129.201
EOF

sudo systemctl restart systemd-resolved

# 2. Configure Docker Desktop DNS
cat > ~/.docker/desktop/daemon.json <<'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1", "62.201.129.202"]
}
EOF

# 3. Restart Docker Desktop
pkill -f "Docker Desktop"
sleep 5
nohup /usr/bin/docker-desktop > /dev/null 2>&1 &

# 4. Wait 30 seconds for startup
sleep 30

# 5. Test
docker pull alpine:latest

# 6. If successful, build ISO
cd /home/lpi/git/Homelab/environments/local
./build-iso.sh
```

## Prevention

To prevent this in the future:

1. Pin DNS servers in `/etc/systemd/resolved.conf.d/dns.conf`
2. Configure Docker Desktop DNS permanently
3. Monitor systemd-resolved: `journalctl -f -u systemd-resolved`
4. Consider using native Docker instead of Docker Desktop
