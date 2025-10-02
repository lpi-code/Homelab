# Data sources for Ansible integration
# This file provides integration between Terraform and Ansible inventory

# External data source to query Ansible inventory
data "external" "ansible_host" {
  program = ["python3", "../../../shared/scripts/terraform/ansible_data_source.py"]
  
  query = {
    hostname = var.target_host
    environment = var.environment
  }
}

# External data source to get all hosts in environment
data "external" "ansible_environment_hosts" {
  program = ["python3", "../../../shared/scripts/terraform/ansible_data_source.py"]
  
  query = {
    list_environment = var.environment
  }
}

# Local values to parse Ansible data
locals {
  # Parse Ansible host data
  ansible_host_data = jsondecode(data.external.ansible_host.result.ansible_data)
  terraform_vars = jsondecode(data.external.ansible_host.result.terraform_vars)
  
  # Parse environment hosts data
  environment_hosts = jsondecode(data.external.ansible_environment_hosts.result.hosts)
  
  # Extract commonly used variables
  proxmox_node = local.terraform_vars["proxmox_node"]
  storage_pool = local.terraform_vars["storage_pool"]
  cluster_name = local.terraform_vars["cluster_name"]
  vm_id = local.terraform_vars["vm_id"]
  vm_memory = local.terraform_vars["vm_memory"]
  vm_cores = local.terraform_vars["vm_cores"]
  vm_disk_size = local.terraform_vars["vm_disk_size"]
  vm_network = local.terraform_vars["vm_network"]
  vm_template = var.vm_template_override != null ? var.vm_template_override : local.terraform_vars["vm_template"]
  vm_tags = split(",", local.terraform_vars["vm_tags"])
  
  # Network configuration from Ansible
  network_cidr = local.ansible_host_data["network"]["cidr"]
  network_gateway = local.ansible_host_data["network"]["gateway"]
  dns_servers = local.ansible_host_data["network"]["dns_servers"]
  
  # Proxmox configuration from Ansible
  proxmox_api_url = local.ansible_host_data["proxmox"]["api_url"]
  proxmox_storage_pool = local.ansible_host_data["proxmox"]["storage_pool"]
  
  # Kubernetes configuration from Ansible
  k8s_version = local.ansible_host_data["kubernetes"]["version"]
  k8s_cni = local.ansible_host_data["kubernetes"]["cni"]
  k8s_pod_cidr = local.ansible_host_data["kubernetes"]["pod_cidr"]
  k8s_service_cidr = local.ansible_host_data["kubernetes"]["service_cidr"]
}

# Output Ansible integration data
output "ansible_integration" {
  description = "Ansible integration data for validation"
  value = {
    host_data = local.ansible_host_data
    terraform_vars = local.terraform_vars
    environment_hosts = local.environment_hosts
    success = data.external.ansible_host.result.success
    error = data.external.ansible_host.result.error
  }
}

# Output parsed configuration
output "parsed_configuration" {
  description = "Parsed configuration from Ansible"
  value = {
    proxmox = {
      node = local.proxmox_node
      api_url = local.proxmox_api_url
      storage_pool = local.proxmox_storage_pool
    }
    network = {
      cidr = local.network_cidr
      gateway = local.network_gateway
      dns_servers = local.dns_servers
    }
    kubernetes = {
      version = local.k8s_version
      cni = local.k8s_cni
      pod_cidr = local.k8s_pod_cidr
      service_cidr = local.k8s_service_cidr
    }
    vm_config = {
      id = local.vm_id
      memory = local.vm_memory
      cores = local.vm_cores
      disk_size = local.vm_disk_size
      network = local.vm_network
      template = local.vm_template
      tags = local.vm_tags
    }
  }
}
