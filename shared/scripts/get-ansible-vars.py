#!/usr/bin/env python3
"""
Script to extract Ansible variables for Terraform consumption.
This script reads Ansible inventory and group_vars to provide variables
directly to Terraform without intermediate files.
"""

import json
import sys
import os
import yaml
from pathlib import Path
import argparse


def load_yaml_file(file_path):
    """Load and parse a YAML file."""
    try:
        with open(file_path, 'r') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file {file_path}: {e}", file=sys.stderr)
        return {}


def get_inventory_hosts(inventory_path):
    """Parse Ansible inventory to get host information."""
    hosts = {}
    try:
        with open(inventory_path, 'r') as f:
            content = f.read()
            # Simple TOML parsing for hosts
            current_group = None
            for line in content.split('\n'):
                line = line.strip()
                if line.startswith('[') and line.endswith(']'):
                    current_group = line[1:-1]
                elif line and not line.startswith('#') and '=' in line:
                    hostname = line.split('=')[0].strip()
                    hosts[hostname] = {'group': current_group}
    except FileNotFoundError:
        pass
    return hosts


def collect_group_vars(environment_path, hostname):
    """Collect variables from group_vars hierarchy."""
    vars_data = {}
    
    # Load all group variables
    group_vars_path = Path(environment_path) / "ansible" / "group_vars"
    if group_vars_path.exists():
        for group_file in group_vars_path.rglob("*.yaml"):
            group_vars = load_yaml_file(group_file)
            vars_data.update(group_vars)
    
    # Load host-specific variables
    host_vars_path = Path(environment_path) / "ansible" / "host_vars" / hostname
    if host_vars_path.exists():
        for host_file in host_vars_path.rglob("*.yaml"):
            host_vars = load_yaml_file(host_file)
            vars_data.update(host_vars)
    
    return vars_data


def convert_ansible_to_terraform_vars(ansible_vars):
    """Convert Ansible variable names and types to Terraform format."""
    tf_vars = {}
    
    # Direct mappings
    direct_mappings = {
        'cluster_name': 'cluster_name',
        'talos_version': 'talos_version',
        'control_plane_count': 'control_plane_count',
        'worker_count': 'worker_count',
        'control_plane_vm_ids': 'control_plane_vm_ids',
        'control_plane_ips': 'control_plane_ips',
        'control_plane_cores': 'control_plane_cores',
        'control_plane_memory': 'control_plane_memory',
        'control_plane_disk_size': 'control_plane_disk_size',
        'worker_vm_ids': 'worker_vm_ids',
        'worker_ips': 'worker_ips',
        'worker_cores': 'worker_cores',
        'worker_memory': 'worker_memory',
        'worker_disk_size': 'worker_disk_size',
        'bridge_name': 'bridge_name',
        'talos_network_cidr': 'talos_network_cidr',
        'talos_network_gateway': 'talos_network_gateway',
        'management_network_cidr': 'management_network_cidr',
        'management_gateway': 'management_gateway',
        'enable_nat_gateway': 'enable_nat_gateway',
        'nat_gateway_vm_id': 'nat_gateway_vm_id',
        'nat_gateway_management_ip': 'nat_gateway_management_ip',
        'nat_gateway_cluster_ip': 'nat_gateway_cluster_ip',
        'openwrt_version': 'openwrt_version',
        'enable_firewall': 'enable_firewall',
        'ssh_public_keys': 'ssh_public_keys',
    }
    
    for ansible_key, terraform_key in direct_mappings.items():
        if ansible_key in ansible_vars:
            tf_vars[terraform_key] = ansible_vars[ansible_key]
    
    # Add computed values
    tf_vars['proxmox_node'] = ansible_vars.get('inventory_hostname', 'pve02')
    tf_vars['storage_pool'] = ansible_vars.get('proxmox_default_storage_pool', 'storage-vms')
    
    return tf_vars


def main():
    parser = argparse.ArgumentParser(description='Extract Ansible variables for Terraform')
    parser.add_argument('--environment', required=True, help='Environment name (dev, prod)')
    parser.add_argument('--host', required=True, help='Target hostname')
    parser.add_argument('--format', choices=['json', 'terraform'], default='json',
                       help='Output format')
    
    args = parser.parse_args()
    
    # Determine environment path
    workspace_root = Path(__file__).parent.parent.parent
    environment_path = workspace_root / "environments" / args.environment
    
    if not environment_path.exists():
        print(f"Environment path not found: {environment_path}", file=sys.stderr)
        sys.exit(1)
    
    # Collect variables
    ansible_vars = collect_group_vars(environment_path, args.host)
    terraform_vars = convert_ansible_to_terraform_vars(ansible_vars)
    
    # Output in requested format
    if args.format == 'json':
        print(json.dumps(terraform_vars, indent=2))
    elif args.format == 'terraform':
        for key, value in terraform_vars.items():
            if isinstance(value, str):
                print(f'{key} = "{value}"')
            elif isinstance(value, bool):
                print(f'{key} = {str(value).lower()}')
            elif isinstance(value, (list, dict)):
                print(f'{key} = {json.dumps(value)}')
            else:
                print(f'{key} = {value}')


if __name__ == '__main__':
    main()