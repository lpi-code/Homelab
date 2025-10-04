# 🌐 OpenWrt Automated Setup Guide

## Overview

This module provides **fully automated OpenWrt router deployment** for Talos Kubernetes clusters with zero manual configuration required.

## 🚀 Quick Setup

### 1. Enable in Your Configuration

```hcl
module "talos_cluster" {
  source = "../../../shared/terraform/modules/talos-cluster"
  
  # ... other configuration ...
  
  # OpenWrt NAT Gateway Configuration
  enable_nat_gateway = true
  nat_gateway_vm_id = 200
  nat_gateway_management_ip = "192.168.0.200"  # WAN IP
  nat_gateway_cluster_ip = "10.10.0.1"         # LAN IP (must be the gateway)
  nat_gateway_password = "secure-password"      # OpenWrt root password
  openwrt_version = "23.05.5"                   # OpenWrt version
  iso_pool = "local"                            # ISO storage pool
}
```

### 2. Run Terraform

```bash
terraform init
terraform plan
terraform apply
```

That's it! The automation will:
1. ✅ Download OpenWrt x86-64 image (EFI)
2. ✅ Create VM with dual network interfaces
3. ✅ Boot OpenWrt (waits 60 seconds)
4. ✅ Configure via SSH using UCI
5. ✅ Set up NAT/Masquerading
6. ✅ Configure firewall rules
7. ✅ Set root password
8. ✅ Ready to use!

## ⏱️ Deployment Time

- **Download**: ~30 seconds (first time only, cached after)
- **Boot**: ~60 seconds
- **Configuration**: ~30 seconds
- **Total**: ~2-3 minutes

## 🌐 After Deployment

### Web Interface (LuCI)

Access the OpenWrt web interface:

```
URL: http://10.10.0.1  (or your nat_gateway_cluster_ip)
Login: root
Password: (your nat_gateway_password)
```

### SSH Access

```bash
# Via LAN (cluster network)
ssh root@10.10.0.1

# Via WAN (management network)
ssh root@192.168.0.200
```

### View Configuration

```bash
# Network configuration
ssh root@10.10.0.1 'uci show network'

# Firewall configuration
ssh root@10.10.0.1 'uci show firewall'

# System info
ssh root@10.10.0.1 'uname -a && cat /etc/openwrt_release'
```

## 🔧 Network Configuration

### Interfaces

| Interface | Name | Network | IP Address | Purpose |
|-----------|------|---------|------------|---------|
| eth0 | WAN | Management | 192.168.0.200 | Internet/Management |
| eth1 | LAN | Cluster | 10.10.0.1 | Talos cluster gateway |

### Firewall Zones

- **WAN Zone**: eth0, input=REJECT, forward=REJECT, output=ACCEPT
- **LAN Zone**: eth1, input=ACCEPT, forward=ACCEPT, output=ACCEPT
- **Forwarding**: LAN → WAN (enabled with NAT/Masquerading)

### NAT Configuration

```bash
# NAT is automatically enabled on WAN
# Masquerading: LAN traffic → WAN
# MTU fix: Enabled for proper packet handling
```

## 🛠️ Manual Configuration (Optional)

If you need to make changes after deployment:

### Change WAN IP

```bash
ssh root@10.10.0.1
uci set network.wan.ipaddr='192.168.0.201'
uci commit network
/etc/init.d/network reload
```

### Change LAN IP

```bash
ssh root@10.10.0.1
uci set network.lan.ipaddr='10.10.0.2'
uci commit network
/etc/init.d/network reload
```

### Add DNS Servers

```bash
ssh root@10.10.0.1
uci add_list network.wan.dns='1.1.1.1'
uci commit network
/etc/init.d/network reload
```

### Enable Additional Services

```bash
ssh root@10.10.0.1
opkg update
opkg install luci-app-statistics  # Monitoring
opkg install luci-app-sqm         # QoS
```

## 🐛 Troubleshooting

### SSH Connection Fails

**Wait longer**: OpenWrt might take more than 60 seconds on slow systems
```bash
# Check if VM is running
ssh root@192.168.0.200  # Try WAN IP instead
```

### No Internet on Talos Nodes

**Check NAT configuration**:
```bash
ssh root@10.10.0.1
# Verify masquerading is enabled
uci show firewall | grep masq

# Should show: firewall.@zone[1].masq='1'
```

### Web UI Not Accessible

**Firewall might be blocking**:
```bash
ssh root@10.10.0.1
# Check if uhttpd is running
/etc/init.d/uhttpd status
/etc/init.d/uhttpd restart
```

### Reset to Defaults

**SSH into OpenWrt and run**:
```bash
firstboot -y && reboot
# Then re-run Terraform apply to reconfigure
```

## 📊 Resource Usage

- **CPU**: 1 core (very low usage)
- **RAM**: 512 MB (OpenWrt uses ~80 MB)
- **Disk**: 1 GB (OpenWrt uses ~128 MB)
- **Network**: 2 virtio interfaces

## 🔐 Security Recommendations

1. **Change Default Password**: Always set a strong password
   ```hcl
   nat_gateway_password = "SuperSecurePassword123!"
   ```

2. **Disable WAN SSH** (optional, only allow LAN):
   ```bash
   ssh root@10.10.0.1
   uci set dropbear.@dropbear[0].Interface='lan'
   uci commit dropbear
   /etc/init.d/dropbear restart
   ```

3. **Enable HTTPS for LuCI**:
   ```bash
   opkg update
   opkg install luci-ssl
   /etc/init.d/uhttpd restart
   # Access via https://10.10.0.1
   ```

4. **Regular Updates**:
   ```bash
   ssh root@10.10.0.1
   opkg update
   opkg list-upgradable
   opkg upgrade <package>
   ```

## 🎯 Use Cases

### 1. Development Clusters
Perfect for homelab Talos clusters that need internet access for:
- Pulling container images
- Downloading packages
- External API access

### 2. Testing Environments
Isolated network with controlled internet access via firewall rules

### 3. Production-like Setup
Simulate real-world network topology with NAT gateway

## 📝 Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `enable_nat_gateway` | Enable OpenWrt NAT gateway | `true` | No |
| `nat_gateway_vm_id` | VM ID for the gateway | `200` | No |
| `nat_gateway_management_ip` | WAN IP address | - | **Yes** |
| `nat_gateway_cluster_ip` | LAN IP (gateway) | - | **Yes** |
| `nat_gateway_password` | Root password | `"openwrt"` | No |
| `openwrt_version` | OpenWrt version | `"23.05.5"` | No |
| `iso_pool` | Storage pool for images | `"local"` | No |

## 🔄 Upgrade Process

To upgrade OpenWrt version:

1. Change `openwrt_version` in your configuration:
   ```hcl
   openwrt_version = "23.05.6"  # New version
   ```

2. Destroy and recreate:
   ```bash
   terraform destroy -target=module.talos_cluster.module.network.proxmox_virtual_environment_vm.nat_gateway
   terraform apply
   ```

3. Or manually upgrade via SSH:
   ```bash
   ssh root@10.10.0.1
   sysupgrade -n https://downloads.openwrt.org/releases/23.05.6/targets/x86/64/openwrt-23.05.6-x86-64-generic-squashfs-combined-efi.img.gz
   ```

## 🌟 Benefits

✅ **Zero Manual Configuration** - Fully automated via Terraform
✅ **Fast Deployment** - Ready in 2-3 minutes
✅ **Lightweight** - Only 512 MB RAM
✅ **Robust** - OpenWrt's proven firewall and routing
✅ **Flexible** - Full UCI configuration access
✅ **Reproducible** - Infrastructure as Code
✅ **Upgradeable** - Easy version management

## 📚 Additional Resources

- [OpenWrt Documentation](https://openwrt.org/docs/start)
- [UCI Configuration](https://openwrt.org/docs/guide-user/base-system/uci)
- [Firewall Configuration](https://openwrt.org/docs/guide-user/firewall/firewall_configuration)
- [LuCI Web Interface](https://openwrt.org/docs/guide-user/luci/start)

