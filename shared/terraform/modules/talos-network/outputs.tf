# Network Module Outputs

output "bridge_name" {
  description = "Name of the created bridge"
  value       = proxmox_virtual_environment_network_linux_bridge.talos_bridge.name
}

output "bridge_ipv4_address" {
  description = "IPv4 address of the bridge"
  value       = proxmox_virtual_environment_network_linux_bridge.talos_bridge.address
}

output "nat_gateway_vm_id" {
  description = "NAT gateway VM ID"
  value       = var.enable_nat_gateway ? module.openwrt_router[0].vm_id : null
}

output "nat_gateway_management_ip" {
  description = "NAT gateway management IP (WAN)"
  value       = var.enable_nat_gateway ? var.nat_gateway_management_ip : null
}

output "nat_gateway_cluster_ip" {
  description = "NAT gateway cluster IP (LAN)"
  value       = var.enable_nat_gateway ? var.nat_gateway_cluster_ip : null
}

output "talos_network_cidr" {
  description = "Talos network CIDR"
  value       = var.talos_network_cidr
}

output "talos_network_gateway" {
  description = "Talos network gateway"
  value       = var.talos_network_gateway
}


