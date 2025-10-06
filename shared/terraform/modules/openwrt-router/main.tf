# OpenWrt Router Module
# Creates OpenWrt router LXC container

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.0"
    }
  }
}

# Create LXC container for OpenWrt
resource "proxmox_virtual_environment_container" "openwrt_router" {
  node_name = var.proxmox_node
  vm_id     = var.router_vm_id
  unprivileged = true
  
  # CPU and Memory
  cpu {
    cores = var.router_cpu_cores
  }
  memory {
    dedicated = var.router_memory
  }

  # Root filesystem
  disk {
    datastore_id = var.storage_pool
    size    = var.router_disk_size
  }

  # Network configuration - Cluster network (LAN)
  network_interface {
    name   = "eth0"
    bridge = var.cluster_bridge
  }
  # Network configuration - Management network (WAN)
  network_interface {
    name   = "eth1"
    bridge = var.management_bridge
  }



  # Container features
  features {
    nesting = true # This is required for OpenWrt to run in a container
  }

  operating_system {
    template_file_id = var.openwrt_template_file_id
  }

}


# # Configure OpenWrt via SSH after container is running
# resource "null_resource" "configure_openwrt" {
#   depends_on = [proxmox_virtual_environment_container.openwrt_router]

#   triggers = {
#     vm_id = proxmox_virtual_environment_container.openwrt_router.vm_id
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       #!/bin/bash
#       set -e
      
#       echo "⏳ Waiting for OpenWrt to boot (60 seconds)..."
#       sleep 60
      
#       echo "🔧 Configuring OpenWrt Router..."
      
#       # SSH into OpenWrt (default: root with no password on LAN)
#       # Configure via SSH using UCI commands
#       ssh-keygen -R ${var.cluster_ip} 2>/dev/null || true
      
#       # Wait for SSH to be available
#       for i in {1..30}; do
#         if timeout 5 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
#            root@${var.cluster_ip} 'echo "SSH Ready"' 2>/dev/null; then
#           echo "✅ SSH connection established"
#           break
#         fi
#         echo "⏳ Waiting for SSH... ($i/30)"
#         sleep 5
#       done
      
#       # Configure OpenWrt
#       ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
#           root@${var.cluster_ip} << 'REMOTE_EOF'
        
#         # Configure WAN interface (eth0)
#         uci set network.wan=interface
#         uci set network.wan.proto='static'
#         uci set network.wan.device='eth0'
#         uci set network.wan.ipaddr='${var.management_ip}'
#         uci set network.wan.netmask='255.255.255.0'
#         uci set network.wan.gateway='${var.management_gateway}'
#         uci set network.wan.dns='8.8.8.8 8.8.4.4'
        
#         # Configure LAN interface (eth1)
#         uci set network.lan.proto='static'
#         uci set network.lan.device='eth1'
#         uci set network.lan.ipaddr='${var.cluster_ip}'
#         uci set network.lan.netmask='255.255.255.0'
        
#         # Enable NAT/Masquerading on WAN
#         uci set firewall.@zone[1].masq='1'
#         uci set firewall.@zone[1].mtu_fix='1'
        
#         # Allow forwarding from LAN to WAN
#         uci set firewall.@forwarding[0].src='lan'
#         uci set firewall.@forwarding[0].dest='wan'
        
#         # Set hostname
#         uci set system.@system[0].hostname='${var.router_name}'
#         uci set system.@system[0].timezone='UTC'
        
#         # Disable IPv6 (optional)
#         uci set network.lan.ipv6='0'
#         uci set network.wan.ipv6='0'
        
#         # Commit all changes
#         uci commit
        
#         # Reload network configuration
#         /etc/init.d/network reload
#         /etc/init.d/firewall reload
        
#         echo "✅ OpenWrt configuration complete!"
# REMOTE_EOF
      
#       echo "🎉 OpenWrt Router configured successfully!"
#       echo "📊 Web UI: http://${var.cluster_ip}"
#       echo "🔑 Login: root / (no password)"
#     EOT
    
#     interpreter = ["/bin/bash", "-c"]
#   }
#}
