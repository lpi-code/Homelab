#!/usr/bin/env python3
"""
Terraform External Data Source for Ansible Integration

This script provides a bridge between Terraform and Ansible by querying
the dynamic inventory system to retrieve host information and variables.

Usage:
    This script is called by Terraform's external data source and expects
    a JSON input with the following parameters:
    - hostname: Name of the host to query
    - environment: Environment to query (optional)
    - inventory_script: Path to the dynamic inventory script

Output:
    JSON object with host information and terraform_vars for use in Terraform

Author: Homelab Infrastructure Team
Version: 1.0.0
"""

import argparse
import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional


class AnsibleDataSource:
    """Terraform external data source for Ansible integration."""
    
    def __init__(self, inventory_script: str = None):
        """Initialize the data source.
        
        Args:
            inventory_script: Path to the dynamic inventory script
        """
        self.inventory_script = inventory_script or self._find_inventory_script()
    
    def _find_inventory_script(self) -> str:
        """Find the dynamic inventory script."""
        repo_root = self._find_repo_root()
        script_path = repo_root / "shared" / "ansible" / "inventory" / "dynamic_inventory.py"
        
        if not script_path.exists():
            raise FileNotFoundError(f"Dynamic inventory script not found: {script_path}")
        
        return str(script_path)
    
    def _find_repo_root(self) -> Path:
        """Find the repository root directory."""
        current = Path.cwd()
        
        # Look for .git directory or environments directory
        while current != current.parent:
            if (current / ".git").exists() or (current / "environments").exists():
                return current
            current = current.parent
        
        # Fallback to current directory
        return Path.cwd()
    
    def get_host_info(self, hostname: str, environment: Optional[str] = None) -> Dict[str, Any]:
        """Get host information from Ansible inventory.
        
        Args:
            hostname: Name of the host
            environment: Environment to query (optional)
            
        Returns:
            Host information dictionary
        """
        try:
            # Build command to query the dynamic inventory
            cmd = [sys.executable, self.inventory_script, "--host", hostname]
            
            if environment:
                cmd.extend(["--env", environment])
            
            # Execute the command
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse the JSON output
            host_data = json.loads(result.stdout)
            
            return {
                "hostname": hostname,
                "environment": environment or "unknown",
                "ansible_data": host_data,
                "terraform_vars": host_data.get("terraform_vars", {}),
                "success": True,
                "error": None
            }
        
        except subprocess.CalledProcessError as e:
            return {
                "hostname": hostname,
                "environment": environment or "unknown",
                "ansible_data": {},
                "terraform_vars": {},
                "success": False,
                "error": f"Command failed: {e.stderr}"
            }
        
        except json.JSONDecodeError as e:
            return {
                "hostname": hostname,
                "environment": environment or "unknown",
                "ansible_data": {},
                "terraform_vars": {},
                "success": False,
                "error": f"JSON decode error: {e}"
            }
        
        except Exception as e:
            return {
                "hostname": hostname,
                "environment": environment or "unknown",
                "ansible_data": {},
                "terraform_vars": {},
                "success": False,
                "error": f"Unexpected error: {e}"
            }
    
    def get_environment_hosts(self, environment: str) -> Dict[str, Any]:
        """Get all hosts for a specific environment.
        
        Args:
            environment: Environment name
            
        Returns:
            Environment hosts information
        """
        try:
            # Build command to list environment hosts
            cmd = [sys.executable, self.inventory_script, "--list", "--env", environment]
            
            # Execute the command
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse the JSON output
            inventory_data = json.loads(result.stdout)
            
            # Extract hosts from the inventory
            hosts = []
            if "all" in inventory_data and "children" in inventory_data["all"]:
                def extract_hosts(data, prefix=""):
                    if isinstance(data, dict):
                        for key, value in data.items():
                            if key == "hosts" and isinstance(value, dict):
                                for hostname in value.keys():
                                    hosts.append(f"{prefix}{hostname}")
                            elif isinstance(value, dict):
                                extract_hosts(value, f"{prefix}{key}/")
                
                extract_hosts(inventory_data["all"]["children"])
            
            return {
                "environment": environment,
                "hosts": hosts,
                "inventory_data": inventory_data,
                "success": True,
                "error": None
            }
        
        except Exception as e:
            return {
                "environment": environment,
                "hosts": [],
                "inventory_data": {},
                "success": False,
                "error": f"Error getting environment hosts: {e}"
            }


def main():
    """Main entry point for the Terraform data source."""
    parser = argparse.ArgumentParser(
        description="Terraform External Data Source for Ansible Integration"
    )
    
    parser.add_argument(
        '--hostname',
        type=str,
        required=True,
        help='Name of the host to query'
    )
    
    parser.add_argument(
        '--environment',
        type=str,
        help='Environment to query'
    )
    
    parser.add_argument(
        '--inventory-script',
        type=str,
        help='Path to the dynamic inventory script'
    )
    
    parser.add_argument(
        '--list-environment',
        type=str,
        help='List all hosts in the specified environment'
    )
    
    args = parser.parse_args()
    
    # Initialize data source
    data_source = AnsibleDataSource(inventory_script=args.inventory_script)
    
    try:
        if args.list_environment:
            # List environment hosts
            result = data_source.get_environment_hosts(args.list_environment)
        else:
            # Get host information
            result = data_source.get_host_info(args.hostname, args.environment)
        
        # Output JSON result for Terraform
        print(json.dumps(result, indent=2))
        
        # Exit with error code if operation failed
        if not result.get("success", False):
            sys.exit(1)
    
    except Exception as e:
        error_result = {
            "success": False,
            "error": f"Unexpected error: {e}"
        }
        print(json.dumps(error_result, indent=2))
        sys.exit(1)


if __name__ == "__main__":
    main()