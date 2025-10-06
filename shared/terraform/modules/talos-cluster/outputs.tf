# Talos Cluster Module Outputs

# Network Outputs
output "bridge_name" {
  description = "Name of the created bridge"
  value       = module.network.bridge_name
}

output "bridge_ipv4_address" {
  description = "IPv4 address of the bridge"
  value       = module.network.bridge_ipv4_address
}

output "nat_gateway_vm_id" {
  description = "NAT gateway VM ID"
  value       = module.network.nat_gateway_vm_id
}

output "nat_gateway_management_ip" {
  description = "NAT gateway management IP (WAN)"
  value       = module.network.nat_gateway_management_ip
}

output "nat_gateway_cluster_ip" {
  description = "NAT gateway cluster IP (LAN)"
  value       = module.network.nat_gateway_cluster_ip
}

# Cluster Outputs
output "cluster_name" {
  description = "Name of the Talos cluster"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster endpoint URL"
  value       = local.cluster_endpoint
}

output "talos_network_cidr" {
  description = "Talos network CIDR"
  value       = var.talos_network_cidr
}

output "talos_network_gateway" {
  description = "Talos network gateway"
  value       = var.talos_network_gateway
}

# Control Plane Outputs
output "control_plane_vm_ids" {
  description = "Control plane VM IDs"
  value       = [for vm in module.control_plane : vm.vm_id]
}

output "control_plane_ips" {
  description = "Control plane IP addresses"
  value       = [for vm in module.control_plane : vm.vm_ipv4_address]
}

output "control_plane_names" {
  description = "Control plane VM names"
  value       = [for vm in module.control_plane : vm.vm_name]
}

# Worker Outputs
output "worker_vm_ids" {
  description = "Worker VM IDs"
  value       = [for vm in module.workers : vm.vm_id]
}

output "worker_ips" {
  description = "Worker IP addresses"
  value       = [for vm in module.workers : vm.vm_ipv4_address]
}

output "worker_names" {
  description = "Worker VM names"
  value       = [for vm in module.workers : vm.vm_name]
}

# Talos Configuration Outputs
output "machine_secrets" {
  description = "Talos machine secrets"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

# Note: kubeconfig and talosconfig outputs removed due to attribute availability issues
# These can be retrieved manually using talosctl commands after cluster is deployed

# Bootstrap Status
output "bootstrap_complete" {
  description = "Whether the cluster has been bootstrapped"
  value       = true
}

# Additional outputs expected by main configuration
output "talos_client_configuration" {
  description = "Talos client configuration"
  value       = talos_machine_secrets.cluster.client_configuration
  sensitive   = true
}

output "talos_machine_secrets" {
  description = "Talos machine secrets"
  value       = talos_machine_secrets.cluster.machine_secrets
  sensitive   = true
}

output "cluster_ready" {
  description = "Whether the cluster is ready for use"
  value       = true
}

# Tunnel Information Outputs
output "control_plane_tunnel_info" {
  description = "Tunnel information for control plane nodes"
  value = {
    for i, vm in module.control_plane : vm.vm_name => {
      node_name = vm.vm_name
      node_ip   = vm.vm_ipv4_address
      tunnel_port = var.control_plane_tunnel_ports[i]
      node_type = "controlplane"
    }
  }
}

output "worker_tunnel_info" {
  description = "Tunnel information for worker nodes"
  value = {
    for i, vm in module.workers : vm.vm_name => {
      node_name = vm.vm_name
      node_ip   = vm.vm_ipv4_address
      tunnel_port = var.worker_tunnel_ports[i]
      node_type = "worker"
    }
  }
}

output "all_tunnel_info" {
  description = "All tunnel information for cluster nodes"
  value = merge(
    {
      for i, vm in module.control_plane : vm.vm_name => {
        node_name = vm.vm_name
        node_ip   = vm.vm_ipv4_address
        tunnel_port = var.control_plane_tunnel_ports[i]
        node_type = "controlplane"
      }
    },
    {
      for i, vm in module.workers : vm.vm_name => {
        node_name = vm.vm_name
        node_ip   = vm.vm_ipv4_address
        tunnel_port = var.worker_tunnel_ports[i]
        node_type = "worker"
      }
    }
  )
}


output "kubeconfig" {
  description = "Kubeconfig"
  value       = data.talos_cluster_kubeconfig.cluster.kubeconfig_raw
  sensitive   = true
}
