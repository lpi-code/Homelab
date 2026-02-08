# Packer template for building Proxmox VE libvirt template
# This creates a KVM VM template using unattended Proxmox ISO
# Template can be used by Vagrant for deployment

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    qemu = {
      version = ">= 1.0.10"
      source  = "github.com/hashicorp/qemu"
    }
    vagrant = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

# Variables
variable "vm_name" {
  type        = string
  default     = "proxmox-pve02"
  description = "Name of the VM template"
}

variable "memory" {
  type        = number
  default     = 20480
  description = "Memory in MB (20GB default)"
}

variable "cpus" {
  type        = number
  default     = 8
  description = "Number of CPU cores"
}

variable "disk_size" {
  type        = string
  default     = "220G"
  description = "Disk size (220GB to match production)"
}

variable "iso_path" {
  type        = string
  default     = "../proxmox-pve02-unattended.iso"
  description = "Path to the unattended Proxmox ISO"
}

variable "network_subnet" {
  type        = string
  default     = "192.168.56.0/24"
  description = "Network subnet for management"
}

variable "proxmox_ip" {
  type        = string
  default     = "192.168.56.149"
  description = "IP address for Proxmox host"
}

variable "ssh_username" {
  type        = string
  default     = "root"
  description = "SSH username"
}

variable "ssh_password" {
  type        = string
  default     = "vagrantvagrant"
  description = "SSH password (from unattended install answer file)"
  sensitive   = true
}

variable "bridge_name" {
  type        = string
  default     = "virbr-homelab"
  description = "Bridge interface for VM networking (from homelab-local libvirt network)"
}

variable "ssh_authorized_keys" {
  type        = list(string)
  default     = []
  description = "List of SSH public keys to add to root's authorized_keys"
}

# Vagrant box and HCP Vagrant Box Registry (optional)
variable "box_tag" {
  type        = string
  default     = ""
  description = "HCP box tag, e.g. hashicorp/precise64. Required only when uploading to HCP Vagrant Box Registry."
}

variable "box_version" {
  type        = string
  default     = "1.0.0"
  description = "Semver version for the Vagrant box (used by vagrant-registry when uploading to HCP)."
}

variable "hcp_client_id" {
  type        = string
  default     = env("HCP_CLIENT_ID")
  description = "HCP service principal client ID (or set HCP_CLIENT_ID env). Used only for vagrant-registry upload."
  sensitive   = true
}

variable "hcp_client_secret" {
  type        = string
  default     = env("HCP_CLIENT_SECRET")
  description = "HCP service principal client secret (or set HCP_CLIENT_SECRET env). Used only for vagrant-registry upload."
  sensitive   = true
}

# Source definition for QEMU/KVM
source "qemu" "proxmox-pve02" {
  # VM settings
  vm_name              = var.vm_name
  memory               = var.memory
  cpus                 = var.cpus
  
  # Disk configuration
  disk_size            = var.disk_size
  disk_interface       = "virtio"
  format               = "qcow2"
  
  # ISO configuration
  iso_url              = var.iso_path
  iso_checksum         = "none"  # Local file, no checksum needed
  
  # Network configuration - use bridge to connect to homelab-local network
  # This allows the VM to get its configured static IP (192.168.56.149)
  net_device           = "virtio-net"
  net_bridge           = var.bridge_name
  
  # Boot configuration
  boot_wait            = "5s"
  boot_command         = []  # Unattended ISO handles everything
  
  # SSH configuration - let Packer discover IP via bridge after DHCP
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  # Don't set ssh_host - let Packer detect IP from bridge after DHCP
  ssh_timeout          = "45m"  # Proxmox installation + reboot takes time
  ssh_handshake_attempts = 500
  ssh_wait_timeout     = "45m"
  # Wait longer before connecting to ensure we get the post-reboot IP, not installer IP
  pause_before_connecting = "5s"
  
  # QEMU-specific settings
  accelerator          = "kvm"
  qemu_binary          = "/usr/bin/qemu-system-x86_64"
  
  # Enable nested virtualization with bridge networking
  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "type=q35,accel=kvm"]
  ]
  
  # Display settings (headless)
  headless             = false  # Set to true for CI/CD
  vnc_bind_address     = "0.0.0.0"
  
  # Output settings
  output_directory     = "output-${var.vm_name}"
  shutdown_command     = "shutdown -P now"
}

# Build definition
build {
  sources = ["source.qemu.proxmox-pve02"]
  
  # Wait for Proxmox installation to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for Proxmox installation to complete...'",
      "timeout 1800 bash -c 'until systemctl is-active pveproxy; do sleep 10; done' || true",
      "echo 'Proxmox VE installation complete!'"
    ]
    pause_before = "10s"
  }
  
  # Verify Proxmox is working
  provisioner "shell" {
    inline = [
      "echo 'Verifying Proxmox VE installation...'",
      "pvesh get /version",
      "echo 'Proxmox VE is working!'"
    ]
  }

  # Add SSH authorized keys to root
  provisioner "file" {
    content     = join("\n", var.ssh_authorized_keys)
    destination = "/tmp/ssh_keys_to_add"
  }
  provisioner "shell" {
    inline = [
      "mkdir -p /root/.ssh",
      "chmod 700 /root/.ssh",
      "[ -s /tmp/ssh_keys_to_add ] && cat /tmp/ssh_keys_to_add >> /root/.ssh/authorized_keys",
      "chmod 600 /root/.ssh/authorized_keys",
      "rm -f /tmp/ssh_keys_to_add"
    ]
  }

  # Configure /etc/network/interfaces for DHCP (vmbr0 bridge over enp1s0)
  provisioner "shell" {
    inline = [
      "echo 'Configuring /etc/network/interfaces for DHCP (vmbr0)...'",
      "cat > /etc/network/interfaces << 'EOF'",
      "auto lo",
      "iface lo inet loopback",
      "",
      "auto enp1s0",
      "iface enp1s0 inet manual",
      "",
      "auto enp0s6",
      "iface enp0s6 inet dhcp",
      "    bridge-ports enp0s6",
      "    bridge-stp off",
      "    bridge-fd 0",
      "EOF",
      "cat /etc/network/interfaces"
    ]
  }

  # Add systemd service to generate SSH host keys on first boot (template has none after cleanup)
  provisioner "shell" {
    inline = [
      "mkdir -p /etc/systemd/system",
      "cat > /etc/systemd/system/ssh-gen-keys.service << 'EOF'",
      "[Unit]",
      "Description=Generate SSH host keys if missing",
      "Before=ssh.service",
      "ConditionPathExists=!/etc/ssh/ssh_host_rsa_key",
      "",
      "[Service]",
      "Type=oneshot",
      "ExecStart=/usr/bin/ssh-keygen -A",
      "RemainAfterExit=yes",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "systemctl enable ssh-gen-keys.service"
    ]
  }
  
  # Ensure /etc/hosts has pve02 so Vagrant's hostname step succeeds (grep -w 'pve02')
  provisioner "shell" {
    inline = [
      "grep -q 'pve02' /etc/hosts || echo '127.0.1.1 pve02 pve02' >> /etc/hosts"
    ]
  }

  # Clean up for template
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up for template...'",
      "rm -rf /tmp/*",
      "rm -rf /var/tmp/*",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /etc/machine-id",
      "sync",
      "echo 'Template cleanup complete!'"
    ]
  }

  # Add no-op VAGRANT block so Vagrant's fstab cleanup sed succeeds.
  # When allow_fstab_modification=false, Vagrant still runs: sed -i '/#VAGRANT-BEGIN/,/#VAGRANT-END/d' /etc/fstab
  # That sed fails (non-zero) when no markers exist; adding them makes it succeed.
  provisioner "shell" {
    inline = [
      "echo '' >> /etc/fstab",
      "echo '#VAGRANT-BEGIN' >> /etc/fstab",
      "echo '#VAGRANT-END' >> /etc/fstab",
      "sync"
    ]
  }

  # Post-processor: copy qcow2 to templates/ for direct use and for deploy.sh fallback
  post-processor "shell-local" {
    inline = [
      "echo 'Converting to libvirt format...'",
      "mkdir -p ${path.root}/templates",
      "cp ${path.root}/output-${var.vm_name}/${var.vm_name} ${path.root}/templates/${var.vm_name}.qcow2",
      "echo 'Template ready: ${path.root}/templates/${var.vm_name}.qcow2'"
    ]
  }

  # Chained post-processors: Vagrant box (from QEMU artifact) then optional HCP Vagrant Box Registry upload.
  # The vagrant post-processor creates a libvirt .box at templates/<vm_name>.box.
  # vagrant-registry uploads that box to HCP Vagrant Box Registry (requires box_tag, version, HCP_CLIENT_ID, HCP_CLIENT_SECRET).
  # For local-only builds: comment out the "vagrant-registry" block below so the build does not attempt upload.
  post-processors {
    post-processor "vagrant" {
      output               = "${path.root}/templates/${var.vm_name}.box"
      keep_input_artifact   = true
      compression_level    = 6
    }
    # Uncomment to upload the box to HCP Vagrant Box Registry (set box_tag, box_version, HCP_CLIENT_ID, HCP_CLIENT_SECRET).
    # post-processor "vagrant-registry" {
    #   box_tag             = var.box_tag
    #   version             = var.box_version
    #   client_id           = var.hcp_client_id
    #   client_secret       = var.hcp_client_secret
    #   architecture        = "amd64"
    #   keep_input_artifact = true
    # }
  }
}
