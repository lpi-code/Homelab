# OpenWrt Templates Management Configuration

This directory contains comprehensive Ansible templates and configuration management for OpenWrt routers in the homelab environment.

## Overview

The OpenWrt template management system provides:
- Template-based configuration for network, firewall, DHCP, and system settings
- Consistent router deployment across different environments
- Backup and restore capabilities
- Monitoring and logging configuration
- Package management and service configuration

## Directory Structure

```
shared/ansible/
├── templates/
│   ├── openwrt_config.j2          # Legacy network config template (for 04-router-setup.yml)
│   ├── openwrt-system.j2          # System configuration template
│   ├── openwrt-network.j2         # Network interfaces template
│   ├── openwrt-firewall.j2        # Firewall rules template
│   └── openwrt-dhcp.j2            # DHCP configuration template
├── playbooks/
│   ├── 04-router-setup.yml        # Legacy router setup playbook
│   └── openwrt-management.yml     # Comprehensive management playbook
├── group_vars/
│   └── openwrt_routers/
│       └── main.yaml              # Common variables for all routers
└── environments/dev/ansible/host_vars/rt-1-cluster/
    └── openwrt-config.yaml        # Router-specific configuration
```

## Usage

### 1. Basic Router Setup (Legacy)

The existing `04-router-setup.yml` playbook uses the `openwrt_config.j2` template:

```bash
ansible-playbook -i environments/dev/ansible/inventory/hosts.toml \
  shared/ansible/playbooks/04-router-setup.yml
```

### 2. Comprehensive Router Management

Use the new management playbook for full configuration:

```bash
ansible-playbook -i environments/dev/ansible/inventory/hosts.toml \
  shared/ansible/playbooks/openwrt-management.yml
```

### 3. Environment-Specific Configuration

Each environment can have specific router configurations:

- **Development**: `environments/dev/ansible/host_vars/rt-1-cluster/openwrt-config.yaml`
- **Production**: `environments/prod/ansible/host_vars/rt-1-cluster/openwrt-config.yaml`

## Configuration Variables

### Common Variables (group_vars/openwrt_routers/main.yaml)

| Variable | Description | Default |
|----------|-------------|---------|
| `management_gateway` | Management network gateway | `192.168.0.1` |
| `cluster_gateway` | Cluster network gateway | `10.10.0.1` |
| `dns_servers` | DNS servers list | `["8.8.8.8", "8.8.4.4", "1.1.1.1"]` |
| `ssh_port` | SSH port | `22` |
| `ssh_root_login` | Allow root SSH login | `true` |
| `packages_to_install` | Packages to install | `["luci", "luci-app-firewall", ...]` |
| `services_to_enable` | Services to enable | `["dropbear", "firewall", "network", ...]` |

### Host-Specific Variables

| Variable | Description |
|----------|-------------|
| `cluster_ip` | Router's IP on cluster network |
| `custom_firewall_rules` | Additional firewall rules |
| `port_forwarding` | Port forwarding rules |
| `dhcp_hosts` | Static DHCP assignments |
| `dns_records` | Custom DNS records |
| `monitoring` | Monitoring configuration |
| `backup_enabled` | Enable configuration backup |

## Template Features

### Network Configuration (`openwrt-network.j2`)

- Loopback interface configuration
- WAN interface (management network)
- LAN interface (cluster network)
- VLAN support
- Static routes
- Switch configuration

### Firewall Configuration (`openwrt-firewall.j2`)

- Zone definitions (lan, wan)
- Default firewall rules
- Custom firewall rules
- Port forwarding rules
- IPv6 support

### DHCP Configuration (`openwrt-dhcp.j2`)

- DHCP server configuration
- Static host assignments
- DNS configuration
- Custom DNS records

### System Configuration (`openwrt-system.j2`)

- Hostname and timezone
- NTP server configuration
- SNMP monitoring
- Logging configuration

## Advanced Features

### Backup Management

- Automatic configuration backup before changes
- Configurable retention period
- Backup cleanup

### Monitoring

- SNMP configuration
- System logging
- Performance monitoring

### Package Management

- Automated package installation
- Service management
- Configuration validation

## Security Considerations

- SSH key-based authentication
- Firewall rule management
- Network isolation
- Access control

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Check if SSH service is running
   - Verify firewall rules
   - Confirm network connectivity

2. **Network Configuration Not Applied**
   - Check UCI configuration syntax
   - Restart network service
   - Verify interface assignments

3. **Template Rendering Errors**
   - Check variable definitions
   - Validate Jinja2 syntax
   - Review template logic

### Debug Commands

```bash
# Check network configuration
uci show network

# Check firewall rules
uci show firewall

# Check system configuration
uci show system

# Restart services
/etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dnsmasq restart
```

## Migration from Legacy Setup

To migrate from the legacy `04-router-setup.yml` to the new management system:

1. Update inventory to use new group variables
2. Configure host-specific variables
3. Run the new management playbook
4. Verify configuration consistency

## Contributing

When adding new features:

1. Update relevant templates
2. Add configuration variables
3. Update documentation
4. Test in development environment
5. Update backup procedures if needed

