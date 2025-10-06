# 🚀 Talos VM Module
# Creates a single Talos VM using direct qcow2 disk import
# Built with ❤️ for Kubernetes homelab infrastructure

# 🔧 Local Variables
locals {
  # Generate a unique name if not provided
  vm_name = var.vm_name != null ? var.vm_name : "${var.cluster_name}-${var.node_type}-${var.node_index + 1}"
  
  # Network configuration
  network_config = var.use_static_ip ? {
    ipv4 = {
      address = "${var.static_ip}/${var.network_cidr_suffix}"
      gateway = var.network_gateway
    }
  } : null
}

# 🚀 Create Talos VM from Direct qcow2 Disk
resource "proxmox_virtual_environment_vm" "talos_vm" {
  name      = local.vm_name
  node_name = var.proxmox_node
  vm_id     = var.vm_id
  
  # VM Description with emoji
  description = var.node_type == "controlplane" ? "🛡️ Control Plane Node for ${var.cluster_name}\n🚀 Kubernetes API Server\n🗄️ etcd\n🌐 IP: ${var.static_ip}\n🐧 Talos Linux" : "⚙️ Worker Node for ${var.cluster_name}\n📦 Workload Execution\n🐳 Pod Runtime\n🌐 IP: ${var.static_ip}\n🐧 Talos Linux"

  # CPU configuration
  cpu {
    cores = var.vm_cores
    type  = var.cpu_type
  }

  # Memory configuration
  memory {
    dedicated = var.vm_memory
  }

  # Machine type
  machine = var.machine_type

  # Disk configuration - use direct qcow2 disk import
  disk {
    datastore_id = var.storage_pool
    interface    = "virtio0"
    size         = tonumber(replace(var.vm_disk_size, "G", ""))
    file_format  = "qcow2"
    import_from      = var.disk_image_file_id
  }

  # Network configuration
  network_device {
    bridge = var.network_bridge
    model  = var.network_model
  }

  # Boot configuration
  bios = var.bios_type
  boot_order = ["virtio0"]

  # VM initialization (for static IP configuration)
  dynamic "initialization" {
    for_each = var.use_static_ip ? [1] : []
    content {
      interface = "ide1"
      datastore_id = var.storage_pool
      ip_config {
        ipv4 {
          address = local.network_config.ipv4.address
          gateway = local.network_config.ipv4.gateway
        }
      }
    }
  }

  # QEMU Guest Agent
  agent {
    enabled = var.enable_qemu_agent
    trim    = var.enable_disk_trim
    type    = "virtio"
  }

  # Start VM
  started = var.start_vm

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network_device,
      disk,
    ]
  }

  # Tags for organization
  tags = var.tags

  # Dependencies
  # Note: No template dependency since we use direct qcow2 disk import
}

# Generate Talos machine configuration
data "talos_machine_configuration" "config" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = var.node_type
  machine_secrets  = var.machine_secrets
  config_patches = var.config_patches
}

# Apply Talos configuration to the VM
resource "talos_machine_configuration_apply" "config" {
  client_configuration = var.client_configuration
  machine_configuration_input = data.talos_machine_configuration.config.machine_configuration
  node = "localhost:${var.tunnel_local_port}"
  config_patches = []

  depends_on = [
    proxmox_virtual_environment_vm.talos_vm,
  ]
  timeouts = {
    create = "3m"
    delete = "3m"
    update = "3m"
  }
}


