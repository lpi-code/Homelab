#!/usr/bin/env python3
"""
Dynamic Inventory Script for Homelab Infrastructure

This script discovers inventory files from all environments and merges them
dynamically with environment-specific overrides. It serves as the single source
of truth for Ansible inventory management.

Usage:
    ./dynamic_inventory.py --list          # List all hosts and groups
    ./dynamic_inventory.py --host <host>   # Get host-specific variables
    ./dynamic_inventory.py --list --env dev    # List only dev environment
    ./dynamic_inventory.py --debug             # Enable debug output

Environment Structure:
    environments/
    ├── dev/
    │   └── ansible/
    │       └── inventory/
    │           └── hosts.yaml
    ├── staging/
    │   └── ansible/
    │       └── inventory/
    │           └── hosts.yaml
    └── prod/
        └── ansible/
            └── inventory/
                └── hosts.yaml

Author: Homelab Infrastructure Team
Version: 1.0.0
"""

import argparse
import json
import os
import sys
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DynamicInventory:
    """Dynamic inventory manager for homelab infrastructure."""
    
    def __init__(self, repo_root: str = None, debug: bool = False):
        """Initialize the dynamic inventory manager.
        
        Args:
            repo_root: Root directory of the repository
            debug: Enable debug logging
        """
        if debug:
            logging.getLogger().setLevel(logging.DEBUG)
        
        self.repo_root = Path(repo_root or self._find_repo_root())
        self.environments_dir = self.repo_root / "environments"
        self.debug = debug
        
        if self.debug:
            logger.debug(f"Repository root: {self.repo_root}")
            logger.debug(f"Environments directory: {self.environments_dir}")
    
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
    
    def _load_inventory_file(self, file_path: Path) -> Dict[str, Any]:
        """Load and parse an inventory YAML file.
        
        Args:
            file_path: Path to the inventory file
            
        Returns:
            Parsed inventory data
        """
        try:
            if not file_path.exists():
                if self.debug:
                    logger.debug(f"Inventory file not found: {file_path}")
                return {}
            
            with open(file_path, 'r') as f:
                data = yaml.safe_load(f) or {}
            
            if self.debug:
                logger.debug(f"Loaded inventory from: {file_path}")
                logger.debug(f"Data: {json.dumps(data, indent=2)}")
            
            return data
        
        except Exception as e:
            logger.error(f"Error loading inventory file {file_path}: {e}")
            return {}
    
    def _discover_environments(self) -> List[str]:
        """Discover available environments.
        
        Returns:
            List of environment names
        """
        environments = []
        
        if not self.environments_dir.exists():
            logger.warning(f"Environments directory not found: {self.environments_dir}")
            return environments
        
        for env_dir in self.environments_dir.iterdir():
            if env_dir.is_dir():
                inventory_file = env_dir / "ansible" / "inventory" / "hosts.yaml"
                if inventory_file.exists():
                    environments.append(env_dir.name)
                    if self.debug:
                        logger.debug(f"Found environment: {env_dir.name}")
        
        return sorted(environments)
    
    def _merge_inventories(self, inventories: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
        """Merge multiple inventory files into a single inventory.
        
        Args:
            inventories: Dictionary of environment -> inventory data
            
        Returns:
            Merged inventory data
        """
        merged = {
            "_meta": {
                "hostvars": {},
                "environment_info": {}
            },
            "all": {
                "children": {},
                "vars": {}
            }
        }
        
        # Process each environment's inventory
        for env_name, inventory in inventories.items():
            if self.debug:
                logger.debug(f"Merging inventory for environment: {env_name}")
            
            # Store environment info
            merged["_meta"]["environment_info"][env_name] = {
                "source": str(self.environments_dir / env_name / "ansible" / "inventory" / "hosts.yaml"),
                "hosts_count": 0,
                "groups_count": 0
            }
            
            # Merge the 'all' group children
            if "all" in inventory and "children" in inventory["all"]:
                env_children = inventory["all"]["children"]
                merged["all"]["children"][env_name] = env_children
                
                # Count groups and hosts for this environment
                hosts_count = 0
                groups_count = 0
                
                def count_hosts_and_groups(data):
                    nonlocal hosts_count, groups_count
                    if isinstance(data, dict):
                        for key, value in data.items():
                            if key == "hosts" and isinstance(value, dict):
                                hosts_count += len(value)
                                # Merge host variables
                                for hostname, hostvars in value.items():
                                    if hostname not in merged["_meta"]["hostvars"]:
                                        merged["_meta"]["hostvars"][hostname] = {}
                                    if isinstance(hostvars, dict):
                                        merged["_meta"]["hostvars"][hostname].update(hostvars)
                                        merged["_meta"]["hostvars"][hostname]["environment"] = env_name
                            elif isinstance(value, dict):
                                groups_count += 1
                                count_hosts_and_groups(value)
                
                count_hosts_and_groups(env_children)
                merged["_meta"]["environment_info"][env_name]["hosts_count"] = hosts_count
                merged["_meta"]["environment_info"][env_name]["groups_count"] = groups_count
            
            # Merge environment-specific variables
            if "all" in inventory and "vars" in inventory["all"]:
                env_vars = inventory["all"]["vars"]
                for var_name, var_value in env_vars.items():
                    env_var_name = f"{env_name}_{var_name}"
                    merged["all"]["vars"][env_var_name] = var_value
        
        return merged
    
    def get_inventory(self, environment: Optional[str] = None) -> Dict[str, Any]:
        """Get the complete inventory or environment-specific inventory.
        
        Args:
            environment: Specific environment to filter (optional)
            
        Returns:
            Inventory data
        """
        if self.debug:
            logger.debug(f"Getting inventory for environment: {environment or 'all'}")
        
        # Discover available environments
        available_envs = self._discover_environments()
        
        if not available_envs:
            logger.warning("No environments found")
            return {"all": {"children": {}}, "_meta": {"hostvars": {}}}
        
        # Filter environments if specified
        if environment:
            if environment not in available_envs:
                logger.error(f"Environment '{environment}' not found. Available: {available_envs}")
                return {"all": {"children": {}}, "_meta": {"hostvars": {}}}
            available_envs = [environment]
        
        # Load inventory files for each environment
        inventories = {}
        for env_name in available_envs:
            inventory_file = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.yaml"
            inventories[env_name] = self._load_inventory_file(inventory_file)
        
        # Merge all inventories
        merged_inventory = self._merge_inventories(inventories)
        
        if self.debug:
            logger.debug(f"Final merged inventory: {json.dumps(merged_inventory, indent=2)}")
        
        return merged_inventory
    
    def get_host_vars(self, hostname: str) -> Dict[str, Any]:
        """Get variables for a specific host.
        
        Args:
            hostname: Name of the host
            
        Returns:
            Host variables
        """
        inventory = self.get_inventory()
        return inventory.get("_meta", {}).get("hostvars", {}).get(hostname, {})
    
    def list_environments(self) -> List[str]:
        """List all available environments.
        
        Returns:
            List of environment names
        """
        return self._discover_environments()
    
    def validate_inventory(self) -> Dict[str, Any]:
        """Validate all inventory files and return validation results.
        
        Returns:
            Validation results
        """
        results = {
            "valid": True,
            "environments": {},
            "errors": [],
            "warnings": []
        }
        
        environments = self._discover_environments()
        
        for env_name in environments:
            env_results = {
                "valid": True,
                "errors": [],
                "warnings": [],
                "hosts": [],
                "groups": []
            }
            
            inventory_file = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.yaml"
            inventory = self._load_inventory_file(inventory_file)
            
            # Validate structure
            if not inventory:
                env_results["valid"] = False
                env_results["errors"].append("Empty or invalid inventory file")
                results["valid"] = False
                results["environments"][env_name] = env_results
                continue
            
            if "all" not in inventory:
                env_results["warnings"].append("Missing 'all' group in inventory")
            
            if "all" in inventory and "children" in inventory["all"]:
                # Extract hosts and groups
                def extract_hosts_and_groups(data, prefix=""):
                    if isinstance(data, dict):
                        for key, value in data.items():
                            if key == "hosts" and isinstance(value, dict):
                                for hostname in value.keys():
                                    env_results["hosts"].append(f"{prefix}{hostname}")
                            elif isinstance(value, dict):
                                group_name = f"{prefix}{key}"
                                env_results["groups"].append(group_name)
                                extract_hosts_and_groups(value, f"{group_name}/")
                
                extract_hosts_and_groups(inventory["all"]["children"])
            
            # Check for required fields in host variables
            if "all" in inventory and "children" in inventory["all"]:
                def check_host_vars(data):
                    if isinstance(data, dict):
                        for key, value in data.items():
                            if key == "hosts" and isinstance(value, dict):
                                for hostname, hostvars in value.items():
                                    if not isinstance(hostvars, dict):
                                        env_results["warnings"].append(f"Host {hostname} has no variables")
                                        continue
                                    
                                    # Check for required fields
                                    required_fields = ["ansible_host", "environment", "cluster_role"]
                                    for field in required_fields:
                                        if field not in hostvars:
                                            env_results["warnings"].append(f"Host {hostname} missing required field: {field}")
                            
                            elif isinstance(value, dict):
                                check_host_vars(value)
                
                check_host_vars(inventory["all"]["children"])
            
            results["environments"][env_name] = env_results
            
            if not env_results["valid"]:
                results["valid"] = False
        
        return results


def main():
    """Main entry point for the dynamic inventory script."""
    parser = argparse.ArgumentParser(
        description="Dynamic Inventory Script for Homelab Infrastructure",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list                    # List all hosts and groups
  %(prog)s --host pve02              # Get host-specific variables
  %(prog)s --list --env dev          # List only dev environment
  %(prog)s --debug                   # Enable debug output
  %(prog)s --validate                # Validate all inventory files
  %(prog)s --list-environments       # List available environments
        """
    )
    
    parser.add_argument(
        '--list',
        action='store_true',
        help='List all hosts and groups'
    )
    
    parser.add_argument(
        '--host',
        type=str,
        help='Get host-specific variables'
    )
    
    parser.add_argument(
        '--env',
        type=str,
        help='Filter by specific environment'
    )
    
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug output'
    )
    
    parser.add_argument(
        '--validate',
        action='store_true',
        help='Validate all inventory files'
    )
    
    parser.add_argument(
        '--list-environments',
        action='store_true',
        help='List available environments'
    )
    
    parser.add_argument(
        '--repo-root',
        type=str,
        help='Repository root directory'
    )
    
    args = parser.parse_args()
    
    # Initialize inventory manager
    inventory = DynamicInventory(repo_root=args.repo_root, debug=args.debug)
    
    try:
        if args.list_environments:
            environments = inventory.list_environments()
            print(json.dumps({
                "environments": environments,
                "count": len(environments)
            }, indent=2))
        
        elif args.validate:
            results = inventory.validate_inventory()
            print(json.dumps(results, indent=2))
            
            if not results["valid"]:
                sys.exit(1)
        
        elif args.host:
            host_vars = inventory.get_host_vars(args.host)
            print(json.dumps(host_vars, indent=2))
        
        elif args.list:
            inventory_data = inventory.get_inventory(environment=args.env)
            print(json.dumps(inventory_data, indent=2))
        
        else:
            parser.print_help()
            sys.exit(1)
    
    except Exception as e:
        logger.error(f"Error: {e}")
        if args.debug:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()