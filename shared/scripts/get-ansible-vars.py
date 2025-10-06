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
import subprocess


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


def get_ansible_vars_for_host(hostname, inventory_path):
    """Get all Ansible variables for a host using ansible-inventory."""
    try:
        # Use ansible-inventory to get all variables for the host
        cmd = [
            'ansible-inventory',
            '--inventory', inventory_path,
            '--host', hostname
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running ansible-inventory: {e}", file=sys.stderr)
        print(f"stderr: {e.stderr}", file=sys.stderr)
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing ansible-inventory output: {e}", file=sys.stderr)
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
        'iso_pool': 'iso_pool',
        'proxmox_default_iso_pool': 'proxmox_default_iso_pool',
        'proxmox_user': 'proxmox_user',
        'proxmox_password': 'proxmox_password',
        'openwrt_template_file_id': 'openwrt_template_file_id',
        'talos_image_file_id': 'talos_image_file_id',
    }
    
    for ansible_key, terraform_key in direct_mappings.items():
        if ansible_key in ansible_vars:
            tf_vars[terraform_key] = ansible_vars[ansible_key]
    
    # Add computed values
    tf_vars['proxmox_node'] = ansible_vars.get('proxmox_node', 'pve02')
    tf_vars['storage_pool'] = ansible_vars.get('proxmox_default_storage_pool', 'storage-vms')
    
    # Add missing variables with defaults
    if 'control_plane_disk_size' not in tf_vars:
        tf_vars['control_plane_disk_size'] = '50G'
    if 'worker_disk_size' not in tf_vars:
        tf_vars['worker_disk_size'] = '50G'
    if 'bridge_name' not in tf_vars:
        tf_vars['bridge_name'] = 'vmbr1'
    if 'talos_network_cidr' not in tf_vars:
        tf_vars['talos_network_cidr'] = '10.10.0.0/24'
    if 'talos_network_gateway' not in tf_vars:
        tf_vars['talos_network_gateway'] = '10.10.0.1'
    if 'management_network_cidr' not in tf_vars:
        tf_vars['management_network_cidr'] = '192.168.0.0/24'
    if 'management_gateway' not in tf_vars:
        tf_vars['management_gateway'] = '192.168.0.1'
    if 'enable_nat_gateway' not in tf_vars:
        tf_vars['enable_nat_gateway'] = True
    if 'nat_gateway_vm_id' not in tf_vars:
        tf_vars['nat_gateway_vm_id'] = 200
    if 'nat_gateway_management_ip' not in tf_vars:
        tf_vars['nat_gateway_management_ip'] = '192.168.0.150/24'
    if 'nat_gateway_cluster_ip' not in tf_vars:
        tf_vars['nat_gateway_cluster_ip'] = '10.10.0.200/24'
    if 'openwrt_version' not in tf_vars:
        tf_vars['openwrt_version'] = '23.05.5'
    if 'enable_firewall' not in tf_vars:
        tf_vars['enable_firewall'] = True
    if 'ssh_public_keys' not in tf_vars:
        tf_vars['ssh_public_keys'] = []
    
    return tf_vars


def main():
    parser = argparse.ArgumentParser(description='Extract Ansible variables for Terraform')
    parser.add_argument('--environment', help='Environment name (dev, prod)')
    parser.add_argument('--host', help='Target hostname')
    parser.add_argument('--format', choices=['json', 'terraform'], default='json',
                       help='Output format')
    
    # Handle both command line args and JSON input from Terraform
    # Terraform external data source passes JSON via stdin, not command line
    try:
        # Try to read from stdin first (Terraform external data source)
        import select
        if select.select([sys.stdin], [], [], 0)[0]:
            # Data available on stdin - likely from Terraform
            stdin_data = sys.stdin.read().strip()
            if stdin_data:
                query = json.loads(stdin_data)
                environment = query.get('environment', 'dev')
                host = query.get('host', 'pve02')
            else:
                # Empty stdin, use defaults
                environment = 'dev'
                host = 'pve02'
        else:
            # No stdin data, try command line arguments
            if len(sys.argv) == 2 and sys.argv[1].startswith('{'):
                # Called by Terraform external data source with JSON as argument
                query = json.loads(sys.argv[1])
                environment = query.get('environment', 'dev')
                host = query.get('host', 'pve02')
            else:
                # Called with command line arguments
                args = parser.parse_args()
                environment = args.environment or 'dev'
                host = args.host or 'pve02'
    except (json.JSONDecodeError, ValueError):
        # Fallback to command line arguments
        try:
            args = parser.parse_args()
            environment = args.environment or 'dev'
            host = args.host or 'pve02'
        except:
            environment = 'dev'
            host = 'pve02'
    
    # Determine environment path
    workspace_root = Path(__file__).parent.parent.parent
    environment_path = workspace_root / "environments" / environment
    
    if not environment_path.exists():
        print(f"Environment path not found: {environment_path}", file=sys.stderr)
        sys.exit(1)
    
    # Collect variables using ansible-inventory to get decrypted SOPS values
    ansible_inventory_path = environment_path / "ansible"
    ansible_vars = get_ansible_vars_for_host(host, str(ansible_inventory_path))
    terraform_vars = convert_ansible_to_terraform_vars(ansible_vars)
    
    # Output in requested format
    format_type = 'json'  # Default for Terraform external data source
    if len(sys.argv) > 2:  # Called with command line args
        try:
            args = parser.parse_args()
            format_type = args.format
        except:
            format_type = 'json'
    
    if format_type == 'json':
        # For external data source, all values must be strings
        # Check if called by Terraform external data source
        # Terraform external data source typically has no command line args or stdin input
        is_external_data_source = (len(sys.argv) == 1 and not sys.stdin.isatty())
        
        if is_external_data_source:
            # Called by Terraform external data source - convert all values to strings
            string_vars = {}
            for key, value in terraform_vars.items():
                if isinstance(value, (list, dict)):
                    string_vars[key] = json.dumps(value)
                else:
                    string_vars[key] = str(value)
            print(json.dumps(string_vars))
        else:
            # Called from command line - preserve original types
            print(json.dumps(terraform_vars, indent=2))
    elif format_type == 'terraform':
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
