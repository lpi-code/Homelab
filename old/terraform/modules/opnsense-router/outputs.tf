# OPNsense Router Module Outputs

output "vm_id" {
  description = "VM ID of the OPNsense router"
  value       = proxmox_virtual_environment_vm.opnsense_router.vm_id
}

output "management_ip" {
  description = "Management IP address of the router"
  value       = var.management_ip
}

output "cluster_ip" {
  description = "Cluster IP address of the router"
  value       = var.cluster_ip
}
