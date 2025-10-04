# 🚀 Talos VM Module Outputs
# Useful outputs for integration with other modules

# 🖥️ VM Information
output "vm_id" {
  description = "🆔 VM ID in Proxmox"
  value       = proxmox_virtual_environment_vm.talos_vm.vm_id
}

output "vm_name" {
  description = "🏷️ VM name"
  value       = proxmox_virtual_environment_vm.talos_vm.name
}

output "vm_ipv4_address" {
  description = "🌐 VM IPv4 address"
  value       = var.use_static_ip ? var.static_ip : proxmox_virtual_environment_vm.talos_vm.ipv4_addresses[0][0]
}

output "vm_mac_address" {
  description = "🔗 VM MAC address"
  value       = proxmox_virtual_environment_vm.talos_vm.network_device[0].mac_address
}

output "vm_status" {
  description = "📊 VM startup configuration"
  value       = proxmox_virtual_environment_vm.talos_vm.startup
}

# 🎯 Talos Configuration
output "talos_node_ip" {
  description = "🌐 Talos node IP address for configuration"
  value       = var.use_static_ip ? var.static_ip : proxmox_virtual_environment_vm.talos_vm.ipv4_addresses[0][0]
}

output "talos_machine_config" {
  description = "⚙️ Generated Talos machine configuration"
  value       = data.talos_machine_configuration.config.machine_configuration
  sensitive   = true
}

# 🔧 Configuration Information
output "disk_image_file_id" {
  description = "📁 Full file ID for Proxmox VM disk configuration"
  value       = var.disk_image_file_id
}

# 🎯 Integration Helpers
output "vm_info" {
  description = "📦 Complete VM information for module integration"
  value = {
    vm_id           = proxmox_virtual_environment_vm.talos_vm.vm_id
    vm_name         = proxmox_virtual_environment_vm.talos_vm.name
    vm_ip           = var.use_static_ip ? var.static_ip : proxmox_virtual_environment_vm.talos_vm.ipv4_addresses[0][0]
    vm_startup      = proxmox_virtual_environment_vm.talos_vm.startup
    node_type       = var.node_type
    cluster_name    = var.cluster_name
    disk_image_file_id = var.disk_image_file_id
    tunnel_local_port = var.tunnel_local_port
  }
}

# 🚇 Tunnel Information
output "tunnel_info" {
  description = "🚇 SSH tunnel information for accessing this node"
  value = var.tunnel_local_port != null ? {
    local_port = var.tunnel_local_port
    remote_ip = var.use_static_ip ? var.static_ip : proxmox_virtual_environment_vm.talos_vm.ipv4_addresses[0][0]
    remote_port = 22
    ssh_command = "ssh -L ${var.tunnel_local_port}:${var.use_static_ip ? var.static_ip : proxmox_virtual_environment_vm.talos_vm.ipv4_addresses[0][0]}:22 root@localhost"
    access_url = "localhost:${var.tunnel_local_port}"
  } : null
}


