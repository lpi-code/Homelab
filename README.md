# Homelab Infrastructure

This repository contains the complete infrastructure-as-code setup for a multi-cluster Kubernetes homelab running on Proxmox with Talos Linux and Flux GitOps.

> **Note**: All commands in this documentation assume you're running from the repository root directory.

## 🏗️ Architecture Overview

- **Infrastructure**: Proxmox VE hypervisors
- **Orchestration**: Talos Linux + Kubernetes
- **GitOps**: Flux CD
- **Provisioning**: Terraform
- **Configuration**: Ansible
- **Clusters**: Development, Staging, Production

## 📁 Folder Structure

```
homelab/
├── .github/                          # GitHub workflows and templates
│   ├── workflows/                    # CI/CD pipelines
│   ├── ISSUE_TEMPLATE/              # Issue templates
│   └── PULL_REQUEST_TEMPLATE/       # PR templates
├── clusters/                         # Kubernetes cluster configurations
│   ├── dev/                         # Development cluster
│   │   ├── talos/                   # Talos Linux configs
│   │   │   ├── control-plane/       # Control plane node configs
│   │   │   ├── worker/              # Worker node configs
│   │   │   └── configs/             # Cluster-specific configs
│   │   ├── flux/                    # Cluster-specific Flux GitOps configs
│   │   │   ├── bootstrap/           # Flux bootstrap for this cluster
│   │   │   ├── apps/                # Applications deployed to this cluster
│   │   │   ├── infrastructure/      # Infrastructure for this cluster
│   │   │   └── monitoring/          # Monitoring stack for this cluster
│   │   └── apps/                    # Application configurations
│   │       ├── monitoring/          # Monitoring applications
│   │       ├── networking/          # CNI and networking
│   │       ├── storage/             # Storage solutions
│   │       ├── security/            # Security tools
│   │       └── platform/            # Platform services
│   ├── staging/                     # Staging cluster (same structure as dev)
│   └── prod/                        # Production cluster (same structure as dev)
├── configs/                         # Configuration files
│   ├── proxmox/                     # Proxmox configurations
│   │   ├── nodes/                   # Node-specific configs
│   │   │   ├── pve01/              # Proxmox node 1 configs
│   │   │   ├── pve02/              # Proxmox node 2 configs
│   │   │   └── pve03/              # Proxmox node 3 configs
│   │   └── templates/               # Configuration templates
│   ├── talos/                       # Talos Linux configs
│   │   ├── templates/               # Talos configuration templates
│   │   └── patches/                 # Configuration patches
│   ├── flux/                        # Global Flux templates and common configs
│   │   ├── templates/               # Flux configuration templates
│   │   ├── common-apps/             # Common applications across clusters
│   │   └── infrastructure/          # Common infrastructure components
│   └── secrets/                     # Encrypted secrets
│       ├── encrypted/               # Encrypted secret files
│       └── keys/                    # Encryption keys
├── docs/                            # Documentation
│   ├── architecture/                # Architecture documentation
│   ├── deployment/                  # Deployment guides
│   ├── operations/                  # Operational procedures
│   └── troubleshooting/             # Troubleshooting guides
├── infrastructure/                  # Infrastructure as Code
│   ├── proxmox/                     # Proxmox configurations
│   │   ├── nodes/                   # Node configurations
│   │   │   ├── pve01/              # Node 1 specific configs
│   │   │   ├── pve02/              # Node 2 specific configs
│   │   │   └── pve03/              # Node 3 specific configs
│   │   └── templates/               # Configuration templates
│   ├── terraform/                   # Terraform configurations
│   │   ├── environments/            # Environment-specific configs
│   │   │   ├── dev/                # Development environment
│   │   │   ├── staging/            # Staging environment
│   │   │   └── prod/               # Production environment
│   │   ├── modules/                 # Reusable Terraform modules
│   │   │   ├── proxmox-vm/         # Proxmox VM module
│   │   │   ├── talos-cluster/      # Talos cluster module
│   │   │   └── network/            # Network module
│   │   ├── global/                  # Global Terraform configs
│   │   └── workspaces/              # Terraform workspaces
│   │       ├── dev/                # Dev workspace
│   │       ├── staging/            # Staging workspace
│   │       └── prod/               # Production workspace
│   └── ansible/                     # Ansible playbooks
│       ├── inventory/               # Ansible inventory
│       ├── playbooks/               # Ansible playbooks
│       ├── roles/                   # Ansible roles
│       ├── group_vars/              # Group variables
│       └── host_vars/               # Host variables
├── scripts/                         # Automation scripts
│   ├── proxmox/                     # Proxmox management scripts
│   │   ├── setup/                   # Setup scripts
│   │   ├── maintenance/             # Maintenance scripts
│   │   └── backup/                  # Backup scripts
│   ├── terraform/                   # Terraform helper scripts
│   │   ├── helpers/                 # Helper scripts
│   │   └── validation/              # Validation scripts
│   ├── talos/                       # Talos management scripts
│   │   ├── bootstrap/               # Bootstrap scripts
│   │   ├── upgrade/                 # Upgrade scripts
│   │   └── maintenance/             # Maintenance scripts
│   ├── flux/                        # Flux management scripts
│   │   ├── bootstrap/               # Bootstrap scripts
│   │   └── deploy/                  # Deployment scripts
│   └── utils/                       # Utility scripts
│       ├── common/                  # Common utilities
│       ├── monitoring/              # Monitoring utilities
│       └── backup/                  # Backup utilities
├── tools/                           # Development and operational tools
│   ├── monitoring/                  # Monitoring tools
│   ├── backup/                      # Backup tools
│   ├── security/                    # Security tools
│   └── validation/                  # Validation tools
├── secrets/                         # Secret management
│   ├── encrypted/                   # Encrypted secrets
│   ├── keys/                        # Encryption keys
│   └── templates/                   # Secret templates
└── Scripts/                         # Legacy scripts (to be migrated)
```

## 🔄 Flux GitOps Structure

**Two-level Flux organization:**

1. **Global Templates** (`configs/flux/`):
   - `templates/` - Reusable Flux configuration templates
   - `common-apps/` - Applications used across all clusters
   - `infrastructure/` - Common infrastructure components

2. **Cluster-Specific** (`clusters/{env}/flux/`):
   - `bootstrap/` - Flux bootstrap configuration for this specific cluster
   - `apps/` - Applications deployed only to this cluster
   - `infrastructure/` - Infrastructure specific to this cluster
   - `monitoring/` - Monitoring stack for this cluster

**How it works:**
- Each cluster's Flux points to this repository
- Global templates provide reusable components
- Cluster-specific folders contain what actually gets deployed
- Flux watches the cluster-specific folders for changes

## 🚀 Quick Start

### Prerequisites

- Proxmox VE cluster
- Terraform >= 1.0
- Ansible >= 2.9
- Talos Linux ISO
- Flux CLI

### Getting Started

1. **Configure Proxmox Nodes**
   ```bash
   # Navigate to the setup script (from repository root)
   cd scripts/proxmox/setup/
   
   # Configure PVE02 with custom answer file
   ./setup-unatend-proxmox.sh \
       --distro proxmox \
       --answer-file ../../infrastructure/proxmox/nodes/pve02/unattend_pve02.toml \
       --out /path/to/output/unattended-pve02.iso
   ```

2. **Initialize Terraform**
   ```bash
   cd infrastructure/terraform/environments/dev
   terraform init
   terraform plan
   ```

3. **Bootstrap Talos Cluster**
   ```bash
   cd clusters/dev/talos
   # Configure Talos cluster
   ```

4. **Install Flux**
   ```bash
   cd clusters/dev/flux/bootstrap
   # Bootstrap Flux
   ```

## 📋 Configuration Management

- **Proxmox Configs**: Node-specific configurations in `infrastructure/proxmox/nodes/`
- **Terraform Modules**: Reusable modules in `infrastructure/terraform/modules/`
- **Cluster Configs**: Environment-based configurations
- **Scripts**: Organized by functionality in `scripts/`

## 🔐 Security

- All secrets are encrypted using SOPS
- Encryption keys stored in `secrets/keys/`
- Encrypted secrets in `secrets/encrypted/`
- Access control via Git repository permissions

## 📊 Monitoring

- Prometheus + Grafana stack
- Cluster health monitoring
- Infrastructure monitoring
- Application monitoring

## 🔄 GitOps Workflow

1. **Infrastructure Changes**: Terraform → Proxmox
2. **Cluster Provisioning**: Terraform → Talos
3. **Application Deployment**: Flux → Kubernetes
4. **Configuration Management**: Ansible → All nodes

## 📚 Documentation

- [Architecture](docs/architecture/)
- [Deployment Guide](docs/deployment/)
- [Operations](docs/operations/)
- [Troubleshooting](docs/troubleshooting/)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test thoroughly
4. Submit pull request
5. Review and merge

## 📄 License

[Add your license here]
