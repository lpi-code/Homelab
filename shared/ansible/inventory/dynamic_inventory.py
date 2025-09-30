#!/usr/bin/env python3
"""
Dynamic Inventory Script for Homelab Infrastructure

This script discovers inventory files from all environments and merges them
dynamically with environment-specific overrides. It serves as the single source
of truth for Ansible inventory management.

Features:
- Automatic discovery of environment-specific inventory files
- SOPS decryption support for encrypted secrets (with age keys)
- Dynamic merging of host variables and secrets
- Environment filtering and validation

Usage:
    ./dynamic_inventory.py --list          # List all hosts and groups
    ./dynamic_inventory.py --host <host>   # Get host-specific variables
    ./dynamic_inventory.py --list --env dev    # List only dev environment
    ./dynamic_inventory.py --debug             # Enable debug output

Environment Structure:
    environments/
    ├── dev/
    │   └── ansible/
    │       ├── inventory/
    │       │   └── hosts.yaml
    │       └── host_vars/
    │           └── <hostname>/
    │               └── secrets.sops.yaml    # SOPS encrypted secrets
    ├── staging/
    │   └── ansible/
    │       └── inventory/
    │           └── hosts.yaml
    └── prod/
        └── ansible/
            └── inventory/
                └── hosts.yaml

SOPS Integration:
- Automatically detects and decrypts SOPS encrypted files
- Supports age key encryption (configured in .sops.yaml)
- Merges decrypted secrets with host variables
- Requires SOPS binary to be available in PATH

Author: Homelab Infrastructure Team
Version: 1.1.0
"""

import argparse
import json
import os
import sys
import yaml
import toml
import subprocess
import tempfile
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
        self.sops_available = self._check_sops_availability()
        
        if self.debug:
            logger.debug(f"Repository root: {self.repo_root}")
            logger.debug(f"Environments directory: {self.environments_dir}")
            logger.debug(f"SOPS available: {self.sops_available}")
    
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
    
    def _check_sops_availability(self) -> bool:
        """Check if SOPS is available and working.
        
        Returns:
            True if SOPS is available, False otherwise
        """
        try:
            result = subprocess.run(
                ['sops', '--version'],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
            return False
    
    def _is_sops_encrypted(self, file_path: Path) -> bool:
        """Check if a file is SOPS encrypted.
        
        Args:
            file_path: Path to the file to check
            
        Returns:
            True if the file is SOPS encrypted, False otherwise
        """
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                # Check for SOPS metadata markers
                return 'sops:' in content and 'enc:' in content
        except Exception:
            return False
    
    def _decrypt_sops_file(self, file_path: Path) -> Optional[Dict[str, Any]]:
        """Decrypt a SOPS encrypted file.
        
        Args:
            file_path: Path to the SOPS encrypted file
            
        Returns:
            Decrypted data as dictionary, or None if decryption fails
        """
        if not self.sops_available:
            logger.warning(f"SOPS not available, cannot decrypt {file_path}")
            return None
        
        try:
            # Use SOPS to decrypt the file
            result = subprocess.run(
                ['sops', '--decrypt', str(file_path)],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                logger.error(f"SOPS decryption failed for {file_path}: {result.stderr}")
                return None
            
            # Parse the decrypted YAML
            decrypted_data = yaml.safe_load(result.stdout)
            
            if self.debug:
                logger.debug(f"Successfully decrypted SOPS file: {file_path}")
            
            return decrypted_data or {}
            
        except subprocess.TimeoutExpired:
            logger.error(f"SOPS decryption timeout for {file_path}")
            return None
        except Exception as e:
            logger.error(f"Error decrypting SOPS file {file_path}: {e}")
            return None
    
    def _load_inventory_file(self, file_path: Path) -> Dict[str, Any]:
        """Load and parse an inventory file (YAML or TOML).
        
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
            
            # Check if the file is SOPS encrypted
            if self._is_sops_encrypted(file_path):
                if self.debug:
                    logger.debug(f"Detected SOPS encrypted file: {file_path}")
                data = self._decrypt_sops_file(file_path)
                if data is None:
                    logger.error(f"Failed to decrypt SOPS file: {file_path}")
                    return {}
            else:
                # Load file based on extension
                with open(file_path, 'r') as f:
                    if file_path.suffix == '.toml':
                        data = toml.load(f) or {}
                    else:
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
                # Check for both TOML and YAML inventory files
                inventory_toml = env_dir / "ansible" / "inventory" / "hosts.toml"
                inventory_yaml = env_dir / "ansible" / "inventory" / "hosts.yaml"
                if inventory_toml.exists() or inventory_yaml.exists():
                    environments.append(env_dir.name)
                    if self.debug:
                        logger.debug(f"Found environment: {env_dir.name}")
        
        return sorted(environments)
    
    def _discover_sops_secrets(self, env_name: str) -> Dict[str, Dict[str, Any]]:
        """Discover and load SOPS encrypted secrets for an environment.
        
        Args:
            env_name: Environment name
            
        Returns:
            Dictionary of hostname -> secrets data
        """
        secrets = {}
        env_dir = self.environments_dir / env_name
        
        # Look for host_vars directories
        host_vars_dir = env_dir / "ansible" / "host_vars"
        if host_vars_dir.exists():
            for host_dir in host_vars_dir.iterdir():
                if host_dir.is_dir():
                    # Look for secrets.sops.yaml files
                    secrets_file = host_dir / "secrets.sops.yaml"
                    if secrets_file.exists() and self._is_sops_encrypted(secrets_file):
                        hostname = host_dir.name
                        decrypted_secrets = self._decrypt_sops_file(secrets_file)
                        if decrypted_secrets:
                            secrets[hostname] = decrypted_secrets
                            if self.debug:
                                logger.debug(f"Loaded SOPS secrets for host {hostname} in environment {env_name}")
        
        return secrets
    
    def _load_host_vars(self, env_name: str, hostname: str) -> Dict[str, Any]:
        """Load host variables from host_vars directory.
        
        Args:
            env_name: Environment name
            hostname: Host name
            
        Returns:
            Host variables dictionary
        """
        host_vars = {}
        env_dir = self.environments_dir / env_name
        host_vars_dir = env_dir / "ansible" / "host_vars" / hostname
        
        if host_vars_dir.exists() and host_vars_dir.is_dir():
            # Look for main.yaml or main.yml files
            for main_file in ["main.yaml", "main.yml"]:
                main_path = host_vars_dir / main_file
                if main_path.exists():
                    try:
                        with open(main_path, 'r') as f:
                            data = yaml.safe_load(f) or {}
                            host_vars.update(data)
                        if self.debug:
                            logger.debug(f"Loaded host vars from: {main_path}")
                    except Exception as e:
                        logger.error(f"Error loading host vars from {main_path}: {e}")
        
        return host_vars
    
    def _load_group_vars(self, env_name: str, group_name: str) -> Dict[str, Any]:
        """Load group variables from group_vars directory.
        
        Args:
            env_name: Environment name
            group_name: Group name
            
        Returns:
            Group variables dictionary
        """
        group_vars = {}
        env_dir = self.environments_dir / env_name
        group_vars_dir = env_dir / "ansible" / "group_vars" / group_name
        
        if group_vars_dir.exists() and group_vars_dir.is_dir():
            # Look for main.yaml or main.yml files
            for main_file in ["main.yaml", "main.yml"]:
                main_path = group_vars_dir / main_file
                if main_path.exists():
                    try:
                        with open(main_path, 'r') as f:
                            data = yaml.safe_load(f) or {}
                            group_vars.update(data)
                        if self.debug:
                            logger.debug(f"Loaded group vars from: {main_path}")
                    except Exception as e:
                        logger.error(f"Error loading group vars from {main_path}: {e}")
        
        return group_vars
    
    def _parse_ini_style_inventory(self, file_path: Path) -> Dict[str, Any]:
        """Parse INI-style inventory file (like hosts.toml).
        
        Args:
            file_path: Path to the inventory file
            
        Returns:
            Parsed inventory data
        """
        inventory_data = {}
        current_group = None
        
        try:
            with open(file_path, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    
                    # Skip empty lines and comments
                    if not line or line.startswith('#'):
                        continue
                    
                    # Check for group header [group_name]
                    if line.startswith('[') and line.endswith(']'):
                        current_group = line[1:-1]
                        if current_group not in inventory_data:
                            inventory_data[current_group] = []
                        continue
                    
                    # Add host to current group
                    if current_group and line:
                        inventory_data[current_group].append(line)
                    elif not current_group and line:
                        # Host without group, add to 'all'
                        if 'all' not in inventory_data:
                            inventory_data['all'] = []
                        inventory_data['all'].append(line)
        
        except Exception as e:
            logger.error(f"Error parsing INI-style inventory file {file_path}: {e}")
            return {}
        
        return inventory_data
    
    def _convert_toml_to_ansible_format(self, toml_data: Dict[str, Any], env_name: str) -> Dict[str, Any]:
        """Convert TOML/INI inventory format to Ansible format.
        
        Args:
            toml_data: TOML/INI inventory data
            env_name: Environment name
            
        Returns:
            Ansible-formatted inventory data
        """
        ansible_inventory = {
            "all": {
                "children": [env_name],
                "vars": {}
            }
        }
        
        # Add environment group
        ansible_inventory[env_name] = {
            "children": [],
            "hosts": [],
            "vars": {}
        }
        
        # Process groups
        for group_name, group_data in toml_data.items():
            if group_name == "all":
                # Handle all group - add hosts to environment
                if isinstance(group_data, list):
                    ansible_inventory[env_name]["hosts"].extend(group_data)
                continue
            
            # Add group as child of environment
            ansible_inventory[env_name]["children"].append(group_name)
            
            # Create group structure
            group_structure = {"hosts": []}
            
            if isinstance(group_data, list):
                # Simple host list
                group_structure["hosts"] = group_data
            elif isinstance(group_data, dict):
                # Group with variables
                for key, value in group_data.items():
                    if key == "hosts" and isinstance(value, list):
                        group_structure["hosts"] = value
                    else:
                        group_structure[key] = value
            
            ansible_inventory[group_name] = group_structure
        
        return ansible_inventory
    
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
                "children": [],
                "vars": {}
            }
        }
        
        # Process each environment's inventory
        for env_name, inventory in inventories.items():
            if self.debug:
                logger.debug(f"Merging inventory for environment: {env_name}")
            
            # Load SOPS secrets for this environment
            sops_secrets = self._discover_sops_secrets(env_name)
            
            # Determine inventory file path for environment info
            inventory_toml = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.toml"
            inventory_yaml = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.yaml"
            inventory_source = str(inventory_toml if inventory_toml.exists() else inventory_yaml)
            
            # Store environment info
            merged["_meta"]["environment_info"][env_name] = {
                "source": inventory_source,
                "hosts_count": 0,
                "groups_count": 0,
                "sops_secrets_count": len(sops_secrets)
            }
            
            # Merge inventory structure
            if "all" in inventory and "children" in inventory["all"]:
                # Add environment to top level if not already there
                if env_name not in merged["all"]["children"]:
                    merged["all"]["children"].append(env_name)
                
                # Copy environment group data
                if env_name in inventory:
                    merged[env_name] = inventory[env_name].copy()
                
                # Copy all groups from inventory
                for group_name, group_data in inventory.items():
                    if group_name not in ["all", "_meta"]:
                        merged[group_name] = group_data.copy()
                        if group_name not in merged["all"]["children"]:
                            merged["all"]["children"].append(group_name)
                
                # Count and merge host variables
                hosts_count = 0
                groups_count = len([k for k in inventory.keys() if k not in ["all", "_meta"]])
                
                def process_hosts_in_group(group_data):
                    nonlocal hosts_count
                    if isinstance(group_data, dict) and "hosts" in group_data:
                        host_list = group_data["hosts"]
                        if isinstance(host_list, list):
                            hosts_count += len(host_list)
                            # Process each host
                            for hostname in host_list:
                                if hostname not in merged["_meta"]["hostvars"]:
                                    merged["_meta"]["hostvars"][hostname] = {}
                                
                                # Load host variables from host_vars directory
                                host_vars = self._load_host_vars(env_name, hostname)
                                merged["_meta"]["hostvars"][hostname].update(host_vars)
                                
                                # Set environment
                                merged["_meta"]["hostvars"][hostname]["environment"] = env_name
                                
                                # Merge SOPS secrets for this host
                                if hostname in sops_secrets:
                                    merged["_meta"]["hostvars"][hostname].update(sops_secrets[hostname])
                                    if self.debug:
                                        logger.debug(f"Merged SOPS secrets for host {hostname}")
                
                # Process all groups
                for group_name, group_data in inventory.items():
                    if group_name not in ["all", "_meta"]:
                        process_hosts_in_group(group_data)
                
                merged["_meta"]["environment_info"][env_name]["hosts_count"] = hosts_count
                merged["_meta"]["environment_info"][env_name]["groups_count"] = groups_count
            
            # Merge environment-specific variables
            if "all" in inventory and "vars" in inventory["all"]:
                env_vars = inventory["all"]["vars"]
                for var_name, var_value in env_vars.items():
                    env_var_name = f"{env_name}_{var_name}"
                    merged["all"]["vars"][env_var_name] = var_value
            
            # Load group variables from group_vars directory
            group_vars = self._load_group_vars(env_name, env_name)
            if group_vars:
                for var_name, var_value in group_vars.items():
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
            # Try TOML first, then YAML
            inventory_toml = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.toml"
            inventory_yaml = self.environments_dir / env_name / "ansible" / "inventory" / "hosts.yaml"
            
            if inventory_toml.exists():
                # Parse INI-style inventory file
                raw_data = self._parse_ini_style_inventory(inventory_toml)
                # Convert to Ansible format
                inventories[env_name] = self._convert_toml_to_ansible_format(raw_data, env_name)
            elif inventory_yaml.exists():
                inventories[env_name] = self._load_inventory_file(inventory_yaml)
            else:
                logger.warning(f"No inventory file found for environment {env_name}")
                inventories[env_name] = {}
        
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
    
    # Check for environment variable if no --env specified
    if not hasattr(args, 'env') or args.env is None:
        args.env = os.environ.get('ANSIBLE_INVENTORY_ENV')
    
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
