#!/usr/bin/env python3
"""
Terraform External Data Source for Ansible Integration
This script provides integration between Terraform and Ansible inventory
"""

import json
import sys
import os
import subprocess
import argparse
from pathlib import Path

def get_ansible_inventory_path():
    """Get the path to the Ansible inventory file"""
    # Get the current working directory
    current_dir = Path.cwd()
    
    # Look for inventory files in common locations
    inventory_paths = [
        current_dir / "ansible" / "inventory" / "hosts.toml",
        current_dir / "inventory" / "hosts.toml",
        current_dir.parent / "ansible" / "inventory" / "hosts.toml",
        current_dir.parent.parent / "ansible" / "inventory" / "hosts.toml",
    ]
    
    for path in inventory_paths:
        if path.exists():
            return str(path)
    
    # If not found, try to find it relative to the script location
    script_dir = Path(__file__).parent
    workspace_root = script_dir.parent.parent.parent
    inventory_path = workspace_root / "environments" / "dev" / "ansible" / "inventory" / "hosts.toml"
    
    if inventory_path.exists():
        return str(inventory_path)
    
    raise FileNotFoundError("Could not find Ansible inventory file")

def run_ansible_command(command):
    """Run an Ansible command and return the result"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Ansible command failed: {e.stderr}")

def get_host_data(hostname, environment):
    """Get host data from Ansible inventory"""
    inventory_path = get_ansible_inventory_path()
    
    # Use ansible-inventory to get host data
    command = f"ansible-inventory -i {inventory_path} --host {hostname} --list"
    host_data = run_ansible_command(command)
    
    try:
        return json.loads(host_data)
    except json.JSONDecodeError:
        raise ValueError(f"Failed to parse host data for {hostname}")

def get_environment_hosts(environment):
    """Get all hosts in an environment"""
    inventory_path = get_ansible_inventory_path()
    
    # Use ansible-inventory to get environment hosts
    command = f"ansible-inventory -i {inventory_path} --list"
    inventory_data = run_ansible_command(command)
    
    try:
        inventory = json.loads(inventory_data)
        environment_hosts = inventory.get("_meta", {}).get("hostvars", {})
        
        # Filter hosts by environment
        env_hosts = {}
        for host, vars in environment_hosts.items():
            if vars.get("environment") == environment:
                env_hosts[host] = vars
                
        return env_hosts
    except json.JSONDecodeError:
        raise ValueError("Failed to parse inventory data")

def get_terraform_vars(hostname, environment):
    """Get Terraform variables for a host"""
    host_data = get_host_data(hostname, environment)
    
    # Extract Terraform-relevant variables
    terraform_vars = {
        "proxmox_node": host_data.get("hostname", hostname),
        "storage_pool": host_data.get("proxmox_default_storage_pool", "storage-vms"),
        "cluster_name": host_data.get("cluster_name", "homelab"),
        "vm_id": host_data.get("vm_id", 100),
        "vm_memory": host_data.get("vm_memory", 2048),
        "vm_cores": host_data.get("vm_cores", 2),
        "vm_disk_size": host_data.get("vm_disk_size", "20G"),
        "vm_network": host_data.get("vm_network", "vmbr0"),
        "vm_template": host_data.get("vm_template", "talos-template"),
        "vm_tags": host_data.get("vm_tags", "kubernetes,talos"),
    }
    
    return terraform_vars

def main():
    parser = argparse.ArgumentParser(description="Terraform External Data Source for Ansible")
    parser.add_argument("--hostname", help="Target hostname")
    parser.add_argument("--environment", help="Target environment")
    parser.add_argument("--list-environment", help="List hosts in environment")
    
    args = parser.parse_args()
    
    try:
        if args.list_environment:
            # List hosts in environment
            hosts = get_environment_hosts(args.list_environment)
            result = {
                "success": True,
                "hosts": json.dumps(hosts),
                "error": None
            }
        elif args.hostname and args.environment:
            # Get specific host data
            host_data = get_host_data(args.hostname, args.environment)
            terraform_vars = get_terraform_vars(args.hostname, args.environment)
            
            result = {
                "success": True,
                "ansible_data": json.dumps(host_data),
                "terraform_vars": json.dumps(terraform_vars),
                "error": None
            }
        else:
            raise ValueError("Either --hostname and --environment, or --list-environment must be provided")
            
    except Exception as e:
        result = {
            "success": False,
            "ansible_data": json.dumps({}),
            "terraform_vars": json.dumps({}),
            "error": str(e)
        }
    
    # Output result as JSON
    print(json.dumps(result))

if __name__ == "__main__":
    main()