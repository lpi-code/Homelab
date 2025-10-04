# Homelab Infrastructure

This repository contains the complete infrastructure-as-code setup for a Talos Kubernetes homelab running on Proxmox with an environment-first structure and Ansible as the source of truth.

## 🏗️ Architecture Overview

- **Infrastructure**: Proxmox VE hypervisors
- **Orchestration**: Talos Linux + Kubernetes
- **Provisioning**: Terraform + OpenTofu
- **Configuration**: Ansible (Source of Truth)
- **Networking**: OpenWrt NAT gateway for cluster internet access
- **Environments**: Development, Staging, Production
- **Inventory**: TOML-based inventory with environment separation

## 📁 Project Structure

```
Homelab/
├── environments/                          # Environment-first organization
│   ├── dev/                              # Development environment
│   │   ├── ansible/                      # Dev-specific ansible configs
│   │   │   ├── inventory/
│   │   │   │   └── hosts.toml           # Dev hosts inventory
│   │   │   ├── group_vars/
│   │   │   │   ├── all/                 # Global variables
│   │   │   │   ├── dev/                 # Dev environment variables
│   │   │   │   ├── dev_pve/             # Proxmox VE group variables
│   │   │   │   └── dev_talos/           # Talos cluster variables
│   │   │   └── host_vars/
│   │   │       └── pve02/               # Host-specific variables
│   │   ├── terraform/                   # Dev-specific terraform
│   │   │   ├── main.tf                  # Main cluster configuration
│   │   │   ├── variables.tf             # Variable definitions
│   │   │   ├── outputs.tf               # Output definitions
│   │   │   ├── data-sources.tf          # Ansible data integration
│   │   │   └── terraform.tfvars.example # Example variables
│   │   ├── kubernetes/                  # Dev-specific k8s configs
│   │   │   ├── clusters/
│   │   │   └── apps/
│   │   └── README.md                    # Environment documentation
│   │
│   ├── staging/                         # Staging environment
│   │   └── [same structure as dev]
│   │
│   └── prod/                            # Production environment
│       └── [same structure as dev]
│
├── shared/                              # Shared components across environments
│   ├── ansible/                         # Shared ansible components
│   │   ├── inventory/
│   │   │   └── dynamic_inventory.py    # Dynamic inventory merger
│   │   ├── playbooks/                  # Shared playbooks
│   │   │   ├── 00-post-install-pve.yml # Proxmox post-install
│   │   │   ├── 01-zfs-setup.yml        # ZFS storage setup
│   │   │   ├── 02-create-vm-template.yml # VM template creation
│   │   │   └── 03-deploy-talos-cluster.yml # Cluster deployment
│   │   └── requirements.yaml           # Ansible requirements
│   │
│   ├── terraform/                      # Shared terraform modules
│   │   ├── modules/
│   │   │   ├── talos-network/          # Network infrastructure
│   │   │   ├── talos-vm/               # Individual VM module
│   │   │   ├── talos-cluster/          # Complete cluster module
│   │   │   └── openwrt-router/         # OpenWrt router module
│   │   └── global/                     # Global resources
│   │
│   ├── kubernetes/                     # Shared k8s components
│   │   ├── base/                       # Base manifests
│   │   ├── apps/                       # Shared applications
│   │   └── templates/                  # Kustomize templates
│   │
│   ├── configs/                        # Shared configuration templates
│   │   ├── ansible.cfg                 # Ansible configuration
│   │   └── sops.yaml                   # SOPS configuration
│   │
│   ├── scripts/                        # Shared scripts
│   │   └── setup-unatend-proxmox.sh    # Proxmox setup script
│   │
│   └── requirements/                   # Python requirements
│       ├── requirements.txt            # Python dependencies
│       └── requirements.yaml           # Ansible collections
│
├── docs/                               # Documentation
│   ├── deployment/
│   │   └── README-setup-unatend-proxmox.md
│   └── gitops/
│       └── SOPS_SETUP.md
├── LICENSE                             # Project license
└── README.md                           # This file
```

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- Ansible 2.9+
- OpenTofu 1.6+ (or Terraform 1.0+)
- Proxmox VE cluster
- SSH access to target hosts

### Installation

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd Homelab
   ```

2. **Install dependencies**
   ```bash
   pip install -r shared/requirements/requirements.txt
   ansible-galaxy install -r shared/requirements/requirements.yaml
   ```

3. **Configure SSH access**
   ```bash
   ssh-copy-id root@192.168.0.149  # Replace with your Proxmox IP
   ```

4. **Configure environment variables**
   ```bash
   export ANSIBLE_ENVIRONMENT=dev
   export SHARED_DIR_PATH=/path/to/Homelab/shared
   ```

### Basic Usage

```bash
# Test connectivity to Proxmox
ansible dev -m ping -i environments/dev/ansible/inventory/hosts.toml

# Deploy Talos cluster
cd environments/dev/terraform
tofu init
tofu plan
tofu apply

# Access the cluster
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

## 🔧 Key Features

### Environment-First Architecture

- **Clear Separation**: Each environment (dev/staging/prod) has its own configuration
- **Shared Components**: Common Terraform modules and Ansible playbooks
- **Consistent Structure**: Same layout across all environments
- **Scalable**: Easy to add new environments

### Talos Kubernetes Cluster

- **Immutable OS**: Talos Linux for security and reliability
- **Automated Deployment**: Complete cluster setup with OpenTofu
- **OpenWrt NAT Gateway**: Automated internet access for cluster nodes
- **High Availability**: Multiple control plane nodes with load balancing

### Infrastructure as Code

- **OpenTofu/Terraform**: Infrastructure provisioning and management
- **Ansible**: Configuration management and orchestration
- **SOPS**: Encrypted secrets management
- **Version Control**: All configurations tracked in Git

## 📋 Usage Examples

### Ansible Operations

```bash
# Test connectivity to Proxmox nodes
ansible dev -m ping -i environments/dev/ansible/inventory/hosts.toml

# Run Proxmox post-install setup
ansible-playbook shared/ansible/playbooks/00-post-install-pve.yml -i environments/dev/ansible/inventory/hosts.toml

# Setup ZFS storage
ansible-playbook shared/ansible/playbooks/01-zfs-setup.yml -i environments/dev/ansible/inventory/hosts.toml

# Deploy Talos cluster
ansible-playbook shared/ansible/playbooks/03-deploy-talos-cluster.yml -i environments/dev/ansible/inventory/hosts.toml
```

### OpenTofu Operations

```bash
# Navigate to environment
cd environments/dev/terraform

# Initialize and plan
tofu init
tofu plan

# Apply infrastructure
tofu apply

# View outputs
tofu output
```

### Cluster Management

```bash
# Get cluster information
tofu output cluster_info

# Access cluster with kubectl
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes

# Access cluster with talosctl
export TALOSCONFIG=./talos_client_configuration.yaml
talosctl get nodes
```

## 🔐 Security

- All secrets encrypted using SOPS
- SSH key-based authentication
- Environment-specific access controls
- Encrypted secret storage in `secrets/` directory

## 📚 Documentation

- **[Development Environment](environments/dev/README.md)**: Dev environment setup and usage
- **[Terraform Modules](shared/terraform/modules/README.md)**: Module documentation
- **[Proxmox Setup](docs/deployment/README-setup-unatend-proxmox.md)**: Proxmox installation guide
- **[SOPS Setup](docs/gitops/SOPS_SETUP.md)**: Secrets management guide

## 🧪 Testing

```bash
# Test connectivity to Proxmox
ansible dev -m ping -i environments/dev/ansible/inventory/hosts.toml

# Validate Terraform configuration
cd environments/dev/terraform
tofu validate

# Plan infrastructure changes
tofu plan

# Test Ansible playbooks in check mode
ansible-playbook shared/ansible/playbooks/00-post-install-pve.yml -i environments/dev/ansible/inventory/hosts.toml --check
```

## 🤝 Contributing

1. Follow the environment-first structure
2. Update inventory files for new hosts
3. Use shared Terraform modules and Ansible playbooks
4. Maintain environment isolation
5. Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Check environment-specific README files for setup issues
- Review module documentation for configuration questions
- Create issues for bugs or feature requests
- Check troubleshooting sections in documentation
