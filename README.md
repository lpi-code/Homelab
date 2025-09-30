# Homelab Infrastructure

This repository contains the complete infrastructure-as-code setup for a multi-cluster Kubernetes homelab running on Proxmox with Talos Linux and Flux GitOps, now reorganized with an environment-first structure and Ansible as the source of truth.

## 🏗️ Architecture Overview

- **Infrastructure**: Proxmox VE hypervisors
- **Orchestration**: Talos Linux + Kubernetes
- **GitOps**: Flux CD
- **Provisioning**: Terraform
- **Configuration**: Ansible (Source of Truth)
- **Environments**: Development, Staging, Production
- **Inventory**: Dynamic inventory with environment discovery

## 📁 New Structure

```
Homelab/
├── environments/                          # Environment-first organization
│   ├── dev/                              # Development environment
│   │   ├── ansible/                      # Dev-specific ansible configs
│   │   │   ├── inventory/
│   │   │   │   └── hosts.yaml           # Dev hosts with terraform_vars
│   │   │   ├── group_vars/
│   │   │   │   ├── dev/
│   │   │   │   │   ├── main.yaml        # Common dev variables
│   │   │   │   │   └── terraform.yaml   # Terraform-specific variables
│   │   │   │   └── all/                 # Shared variables
│   │   │   ├── host_vars/
│   │   │   │   └── dev-hosts/           # Dev-specific host vars
│   │   ├── terraform/                   # Dev-specific terraform
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── data-sources.tf          # Ansible data integration
│   │   │   └── terraform.tfvars
│   │   ├── kubernetes/                  # Dev-specific k8s configs
│   │   │   ├── clusters/
│   │   │   └── apps/
│   │   └── configs/                     # Dev-specific configs
│   │       ├── flux/
│   │       ├── talos/
│   │       └── proxmox/
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
│   │   │   ├── infrastructure/
│   │   │   │   ├── proxmox-setup.yml
│   │   │   │   ├── zfs-setup.yml
│   │   │   │   ├── network-setup.yml
│   │   │   │   └── deploy-cluster.yml
│   │   │   ├── kubernetes/
│   │   │   │   ├── talos-bootstrap.yml
│   │   │   │   └── cluster-setup.yml
│   │   │   └── maintenance/
│   │   │       ├── backup.yml
│   │   │       └── updates.yml
│   │   ├── roles/                      # Shared roles
│   │   │   ├── proxmox/
│   │   │   ├── kubernetes/
│   │   │   └── monitoring/
│   │   └── requirements.yml
│   │
│   ├── terraform/                      # Shared terraform modules
│   │   ├── modules/
│   │   │   ├── network/
│   │   │   ├── proxmox-vm/
│   │   │   ├── talos-cluster/
│   │   │   └── monitoring/
│   │   └── global/                     # Global resources
│   │       ├── providers.tf
│   │       └── backend.tf
│   │
│   ├── kubernetes/                     # Shared k8s components
│   │   ├── base/                       # Base manifests
│   │   ├── apps/                       # Shared applications
│   │   └── templates/                  # Kustomize templates
│   │
│   ├── configs/                        # Shared configuration templates
│   │   ├── flux/
│   │   ├── talos/
│   │   └── proxmox/
│   │
│   └── scripts/                        # Shared scripts
│       ├── ansible/
│       ├── terraform/
│       ├── kubernetes/
│       └── utils/
│
├── docs/                               # Documentation
│   ├── MIGRATION_GUIDE.md             # Migration instructions
│   ├── USAGE_GUIDE.md                 # Usage documentation
│   └── ARCHITECTURE.md                # Architecture details
├── secrets/                            # Encrypted secrets
├── ansible.cfg                         # Updated to use dynamic inventory
├── requirements.yaml                   # Global requirements
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- Ansible 2.9+
- Terraform 1.0+
- Proxmox VE cluster
- SSH access to target hosts

### Installation

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd homelab
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure SSH access**
   ```bash
   ssh-copy-id root@192.168.1.102
   # ... for all hosts
   ```

4. **Test dynamic inventory**
   ```bash
   ./shared/ansible/inventory/dynamic_inventory.py --list-environments
   ```

### Basic Usage

```bash
# List all environments
./shared/ansible/inventory/dynamic_inventory.py --list-environments

# List all hosts
ansible all --list-hosts

# Test connectivity
ansible dev -m ping

# Run infrastructure setup
ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev

# Deploy with Terraform
cd environments/dev/terraform
terraform init
terraform plan -var="target_host=pve02-dev"
```

## 🔧 Key Features

### Dynamic Inventory System

- **Automatic Discovery**: Discovers hosts from all environments
- **Environment Isolation**: Clear separation between dev/staging/prod
- **Single Source of Truth**: Ansible inventory drives all configuration
- **Validation**: Built-in inventory validation and error checking

### Terraform Integration

- **Bidirectional Data Flow**: Terraform queries Ansible for host information
- **No Duplication**: Host variables defined once in Ansible inventory
- **Environment Consistency**: Same variables used across tools
- **State Independence**: Terraform state separate from Ansible data

### Environment Management

- **Environment-First**: Clear separation by environment
- **Shared Components**: Common playbooks, roles, and modules
- **Consistent Structure**: Same layout across all environments
- **Scalable**: Easy to add new environments

## 📋 Usage Examples

### Dynamic Inventory

```bash
# List environments
./shared/ansible/inventory/dynamic_inventory.py --list-environments

# List all hosts
./shared/ansible/inventory/dynamic_inventory.py --list

# List dev environment hosts
./shared/ansible/inventory/dynamic_inventory.py --list --env dev

# Get host variables
./shared/ansible/inventory/dynamic_inventory.py --host pve02-dev

# Validate inventory
./shared/ansible/inventory/dynamic_inventory.py --validate
```

### Ansible Operations

```bash
# Environment targeting
ansible dev -m ping
ansible staging -m ping
ansible prod -m ping

# Group targeting
ansible dev_pve -m ping
ansible dev_k8s_control -m ping

# Playbook execution
ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev
ansible-playbook shared/ansible/playbooks/kubernetes/talos-bootstrap.yml -e target_environment=dev
```

### Terraform Operations

```bash
# Navigate to environment
cd environments/dev/terraform

# Initialize and plan
terraform init
terraform plan -var="target_host=pve02-dev"

# Apply infrastructure
terraform apply -var="target_host=pve02-dev"
```

## 🔐 Security

- All secrets encrypted using SOPS
- SSH key-based authentication
- Environment-specific access controls
- Encrypted secret storage in `secrets/` directory

## 📚 Documentation

- **[Migration Guide](docs/MIGRATION_GUIDE.md)**: Step-by-step migration instructions
- **[Usage Guide](docs/USAGE_GUIDE.md)**: Comprehensive usage documentation
- **[Architecture Guide](docs/ARCHITECTURE.md)**: Detailed architecture overview

## 🧪 Testing

```bash
# Validate inventory
./shared/ansible/inventory/dynamic_inventory.py --validate

# Test connectivity
ansible all -m ping

# Test Terraform integration
./shared/scripts/terraform/ansible_data_source.py --hostname pve02-dev --environment dev

# Run playbook tests
ansible-playbook shared/ansible/playbooks/infrastructure/proxmox-setup.yml -e target_environment=dev --check
```

## 🤝 Contributing

1. Follow the environment-first structure
2. Update inventory files for new hosts
3. Use shared playbooks and roles
4. Maintain environment isolation
5. Update documentation

## 📄 License

<<<<<<< Current (Your changes)
[Add your license here]
=======
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Check [Migration Guide](docs/MIGRATION_GUIDE.md) for setup issues
- Review [Usage Guide](docs/USAGE_GUIDE.md) for operational questions
- Create issues for bugs or feature requests
- Check troubleshooting sections in documentation
>>>>>>> Incoming (Background Agent changes)
