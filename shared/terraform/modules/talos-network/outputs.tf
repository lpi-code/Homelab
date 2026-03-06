# Network Module Outputs

output "bridge_name" {
  description = "Name of the bridge (created by 03a-preflight.ansible.yml)"
  value       = var.bridge_name
}

output "bridge_ipv4_address" {
  description = "IPv4 address of the bridge"
  value       = var.bridge_ipv4_address
}

output "talos_network_cidr" {
  description = "Talos network CIDR"
  value       = var.talos_network_cidr
}

output "talos_network_gateway" {
  description = "Talos network gateway"
  value       = var.talos_network_gateway
}
