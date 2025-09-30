# SOPS and Age Key Setup for Ansible Homelab

## Overview

Your homelab is now configured with SOPS (Secrets OPerationS) for encrypting sensitive data in Ansible playbooks and inventories. This setup uses age encryption for secure key management.

## Current Configuration

### Age Keys
- **Location**: `~/.config/sops/age/keys.txt`
- **Public Key**: `age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6`
- **Private Key**: Stored securely in the keys file

### SOPS Configuration
- **Config File**: `/home/skorll/Homelab/sops.yaml`
- **Encryption Rules**: 
  - Files matching `secrets.(yaml|yml|json|env)$`
  - Files matching `.*\.sops\.(yaml|yml|json)$`

### Ansible Integration
- **Collection**: `community.sops` (version 2.2.2)
- **Vars Plugin**: `community.sops.sops` enabled
- **Configuration**: Updated in `shared/configs/ansible.cfg`

## Key Management

### Generating New Age Keys

#### Generate a New Key Pair
```bash
# Generate a new age key pair
age-keygen -o ~/.config/sops/age/new-key.txt

# This will output something like:
# created: 2025-09-30T10:30:00+02:00
# public key: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890
# AGE-SECRET-KEY-1ABC123DEF456GHI789JKL012MNO345PQR678STU901VWX234YZ567890
```

#### Extract Public Key
```bash
# Extract just the public key from the key file
age-keygen -y ~/.config/sops/age/new-key.txt
# Output: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890
```

### Adding Keys to SOPS Configuration

#### Single Key Setup
```yaml
# sops.yaml
creation_rules:
  - path_regex: 'secrets\.(yaml|yml|json|env)$'
    age: "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"
  - path_regex: '.*\.sops\.(yaml|yml|json)$'
    age: "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"
```

#### Multiple Keys Setup (Team Collaboration)
```yaml
# sops.yaml
creation_rules:
  - path_regex: 'secrets\.(yaml|yml|json|env)$'
    age:
      - "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"  # Admin key
      - "age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"      # Team member 1
      - "age1xyz789uvw456rst123mno890pqr567stu234vwx901yz567890abc123"      # Team member 2
  - path_regex: '.*\.sops\.(yaml|yml|json)$'
    age:
      - "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"
      - "age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
      - "age1xyz789uvw456rst123mno890pqr567stu234vwx901yz567890abc123"
```

#### Environment-Specific Keys
```yaml
# sops.yaml
creation_rules:
  # Development environment
  - path_regex: 'environments/dev/.*secrets\.(yaml|yml|json)$'
    age:
      - "age1dev123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
  
  # Staging environment
  - path_regex: 'environments/staging/.*secrets\.(yaml|yml|json)$'
    age:
      - "age1stg123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
  
  # Production environment (multiple keys for redundancy)
  - path_regex: 'environments/prod/.*secrets\.(yaml|yml|json)$'
    age:
      - "age1prod123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
      - "age1backup123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
```

### Adding Keys to Existing Encrypted Files

#### Add a New Recipient to Existing Files
```bash
# Add a new age key to an existing encrypted file
sops --config sops.yaml --add-age age1newkey123def456ghi789jkl012mno345pqr678stu901vwx234yz567890 path/to/secrets.sops.yaml

# Add multiple keys at once
sops --config sops.yaml \
  --add-age age1key1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567890 \
  --add-age age1key2xyz789uvw456rst123mno890pqr567stu234vwx901yz567890abc123 \
  path/to/secrets.sops.yaml
```

#### Remove a Recipient from Files
```bash
# Remove an age key from an encrypted file
sops --config sops.yaml --rm-age age1oldkey123def456ghi789jkl012mno345pqr678stu901vwx234yz567890 path/to/secrets.sops.yaml
```

### Key Rotation Procedures

#### 1. Generate New Key
```bash
# Generate new key pair
age-keygen -o ~/.config/sops/age/new-rotation-key.txt

# Extract public key
NEW_PUBLIC_KEY=$(age-keygen -y ~/.config/sops/age/new-rotation-key.txt)
echo "New public key: $NEW_PUBLIC_KEY"
```

#### 2. Update SOPS Configuration
```bash
# Backup current config
cp sops.yaml sops.yaml.backup

# Update sops.yaml with new key (add to existing keys)
# Edit the file to include the new public key
```

#### 3. Re-encrypt All Files
```bash
# Find all SOPS encrypted files
find environments/ -name "*.sops.*" -type f

# Re-encrypt each file to include new key
for file in $(find environments/ -name "*.sops.*" -type f); do
  echo "Re-encrypting $file"
  sops --config sops.yaml --add-age "$NEW_PUBLIC_KEY" "$file"
done
```

#### 4. Remove Old Key
```bash
# After confirming new key works, remove old key from all files
OLD_PUBLIC_KEY="age1oldkey123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"

for file in $(find environments/ -name "*.sops.*" -type f); do
  echo "Removing old key from $file"
  sops --config sops.yaml --rm-age "$OLD_PUBLIC_KEY" "$file"
done
```

### Team Collaboration Setup

#### Sharing Keys Securely

1. **Generate Individual Keys**: Each team member generates their own age key pair
2. **Share Public Keys**: Public keys are shared via secure channels (encrypted email, secure chat, etc.)
3. **Update Configuration**: Add all public keys to `sops.yaml`
4. **Re-encrypt Files**: Re-encrypt existing files with all team member keys

#### Example Team Setup Script
```bash
#!/bin/bash
# team-sops-setup.sh

# Team member public keys (replace with actual keys)
TEAM_KEYS=(
  "age1admin123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
  "age1dev123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
  "age1ops123def456ghi789jkl012mno345pqr678stu901vwx234yz567890"
)

# Update sops.yaml with all team keys
cat > sops.yaml << EOF
creation_rules:
  - path_regex: 'secrets\.(yaml|yml|json|env)$'
    age:
$(printf "      - \"%s\"\n" "${TEAM_KEYS[@]}")
  - path_regex: '.*\.sops\.(yaml|yml|json)$'
    age:
$(printf "      - \"%s\"\n" "${TEAM_KEYS[@]}")
EOF

# Re-encrypt all existing files
for file in $(find environments/ -name "*.sops.*" -type f); do
  echo "Re-encrypting $file with team keys"
  for key in "${TEAM_KEYS[@]}"; do
    sops --config sops.yaml --add-age "$key" "$file"
  done
done

echo "Team SOPS setup complete!"
```

### Key Backup and Recovery

#### Backup Keys
```bash
# Create encrypted backup of age keys
tar -czf age-keys-backup-$(date +%Y%m%d).tar.gz ~/.config/sops/age/
gpg --symmetric --cipher-algo AES256 age-keys-backup-$(date +%Y%m%d).tar.gz
rm age-keys-backup-$(date +%Y%m%d).tar.gz

# Store the encrypted backup securely (password manager, secure cloud storage, etc.)
```

#### Restore Keys
```bash
# Restore from encrypted backup
gpg --decrypt age-keys-backup-20250930.tar.gz.gpg | tar -xzf -
```

### Key Validation

#### Verify Key Access
```bash
# Test if you can decrypt a file with your key
sops decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml

# List all recipients for a file
sops --config sops.yaml --list-keys environments/dev/ansible/host_vars/pve02/secrets.sops.yaml
```

#### Check Key Permissions
```bash
# Verify which keys can decrypt a file
for key_file in ~/.config/sops/age/*.txt; do
  if [ -f "$key_file" ]; then
    echo "Testing key: $key_file"
    SOPS_AGE_KEY_FILE="$key_file" sops decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✓ Key can decrypt file"
    else
      echo "✗ Key cannot decrypt file"
    fi
  fi
done
```

## Usage Examples

### Encrypting Files

```bash
# Encrypt a new file
sops --config sops.yaml -e -i path/to/secrets.sops.yaml

# Encrypt and create a new file
sops --config sops.yaml -e -o encrypted.sops.yaml plain.yaml
```

### Decrypting Files

```bash
# Decrypt to stdout
sops decrypt path/to/secrets.sops.yaml

# Decrypt in place
sops --config sops.yaml -d -i path/to/secrets.sops.yaml
```

### Editing Encrypted Files

```bash
# Edit encrypted file (opens in default editor)
sops --config sops.yaml path/to/secrets.sops.yaml
```

### Ansible Integration

The SOPS vars plugin automatically decrypts `.sops.yaml`, `.sops.yml`, and `.sops.json` files in:
- `group_vars/` directories
- `host_vars/` directories

Variables are loaded during inventory parsing and cached for performance.

## File Structure

```
environments/
├── dev/ansible/
│   ├── group_vars/all/secrets.sops.yaml    # Global dev secrets
│   └── host_vars/pve02/secrets.sops.yaml   # Host-specific secrets
├── staging/ansible/
│   └── group_vars/all/secrets.sops.yaml    # Global staging secrets
└── prod/ansible/
    └── group_vars/all/secrets.sops.yaml    # Global prod secrets
```

## Security Best Practices

1. **Never commit unencrypted secrets** to version control
2. **Use different age keys** for different environments if needed
3. **Backup your age keys** securely (consider using a password manager)
4. **Rotate keys regularly** for production environments
5. **Use descriptive variable names** to avoid confusion

## Testing Your Setup

```bash
# Test SOPS decryption
sops decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml

# Test Ansible variable loading
ansible-inventory --host pve02 -i environments/dev/ansible/inventory --vars

# Test with dynamic inventory
ANSIBLE_ENVIRONMENT=dev ansible-inventory --host pve02 -i shared/ansible/inventory/dynamic_inventory.py --vars
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy with SOPS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install SOPS
        run: |
          wget -O sops https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux
          chmod +x sops
          sudo mv sops /usr/local/bin/
      
      - name: Install age
        run: |
          wget -O age.tar.gz https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
          tar -xzf age.tar.gz
          sudo mv age/age /usr/local/bin/
      
      - name: Setup age key
        run: |
          echo "${{ secrets.AGE_PRIVATE_KEY }}" > ~/.config/sops/age/keys.txt
          chmod 600 ~/.config/sops/age/keys.txt
        env:
          AGE_PRIVATE_KEY: ${{ secrets.AGE_PRIVATE_KEY }}
      
      - name: Verify SOPS decryption
        run: |
          sops --config sops.yaml decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml
      
      - name: Run Ansible playbook
        run: |
          ansible-playbook -i environments/dev/ansible/inventory playbooks/deploy.yml
```

### GitLab CI Example

```yaml
# .gitlab-ci.yml
stages:
  - deploy

deploy:
  stage: deploy
  image: python:3.9
  before_script:
    - pip install ansible
    - wget -O sops https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux
    - chmod +x sops && mv sops /usr/local/bin/
    - wget -O age.tar.gz https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
    - tar -xzf age.tar.gz && mv age/age /usr/local/bin/
    - mkdir -p ~/.config/sops/age/
    - echo "$AGE_PRIVATE_KEY" > ~/.config/sops/age/keys.txt
    - chmod 600 ~/.config/sops/age/keys.txt
  script:
    - sops --config sops.yaml decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml
    - ansible-playbook -i environments/dev/ansible/inventory playbooks/deploy.yml
  variables:
    AGE_PRIVATE_KEY: $AGE_PRIVATE_KEY
```

### Setting Up CI/CD Secrets

#### GitHub Actions
1. Go to repository Settings → Secrets and variables → Actions
2. Add new repository secret: `AGE_PRIVATE_KEY`
3. Value should be the content of your age private key file

#### GitLab CI
1. Go to project Settings → CI/CD → Variables
2. Add new variable: `AGE_PRIVATE_KEY`
3. Mark as "Protected" and "Masked"
4. Value should be the content of your age private key file

## Troubleshooting

### Common Issues

1. **"sops metadata not found"**: File is not encrypted with SOPS
2. **"config file not found"**: SOPS can't find the configuration file
3. **"no matching creation rules"**: File path doesn't match any rules in sops.yaml
4. **Variables not loading**: Check that `community.sops.sops` is in `vars_plugins_enabled`
5. **"age: no identity found"**: Age key file not found or not readable
6. **"age: decryption failed"**: Wrong key or corrupted encrypted data
7. **"failed to decrypt data key"**: Key doesn't have permission to decrypt the file

### Key-Related Issues

#### Age Key Problems
```bash
# Check if age key file exists and is readable
ls -la ~/.config/sops/age/keys.txt

# Verify key format
head -1 ~/.config/sops/age/keys.txt
# Should start with: AGE-SECRET-KEY-1

# Test key with specific file
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops decrypt path/to/file.sops.yaml
```

#### Permission Issues
```bash
# Fix key file permissions
chmod 600 ~/.config/sops/age/keys.txt
chmod 700 ~/.config/sops/age/

# Check SOPS can access the key
sops --config sops.yaml --list-keys path/to/file.sops.yaml
```

#### Multiple Key Conflicts
```bash
# Check which keys are configured for a file
sops --config sops.yaml --list-keys path/to/file.sops.yaml

# Test with specific key file
SOPS_AGE_KEY_FILE=/path/to/specific/key.txt sops decrypt path/to/file.sops.yaml
```

### Debug Commands

```bash
# Check SOPS version
sops --version

# Check age installation
age --version

# Check age keys
cat ~/.config/sops/age/keys.txt

# Check Ansible collections
ansible-galaxy collection list | grep sops

# Test SOPS configuration
sops --config sops.yaml --list-keys environments/dev/ansible/host_vars/pve02/secrets.sops.yaml

# Test decryption
sops decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml

# Test with verbose output
ansible-inventory --list -i environments/dev/ansible/inventory --vars -v

# Check environment variables
env | grep -E "(SOPS|AGE)"

# Test key access
for key in ~/.config/sops/age/*.txt; do
  echo "Testing key: $key"
  SOPS_AGE_KEY_FILE="$key" sops decrypt environments/dev/ansible/host_vars/pve02/secrets.sops.yaml
done
```

## Quick Reference

### Essential Commands
```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/new-key.txt

# Extract public key
age-keygen -y ~/.config/sops/age/new-key.txt

# Encrypt file
sops --config sops.yaml -e -i path/to/secrets.sops.yaml

# Decrypt file
sops decrypt path/to/secrets.sops.yaml

# Edit encrypted file
sops --config sops.yaml path/to/secrets.sops.yaml

# Add key to existing file
sops --config sops.yaml --add-age age1newkey123... path/to/secrets.sops.yaml

# Remove key from file
sops --config sops.yaml --rm-age age1oldkey123... path/to/secrets.sops.yaml

# List recipients
sops --config sops.yaml --list-keys path/to/secrets.sops.yaml
```

### File Extensions
- `.sops.yaml` - SOPS encrypted YAML files
- `.sops.yml` - SOPS encrypted YAML files (alternative)
- `.sops.json` - SOPS encrypted JSON files

### Key Locations
- Age keys: `~/.config/sops/age/keys.txt`
- SOPS config: `sops.yaml` (project root)
- Ansible config: `shared/configs/ansible.cfg`

## Next Steps

1. **Encrypt existing plaintext secrets** in your inventory
2. **Create environment-specific secrets** for staging and production
3. **Set up team collaboration** by adding team member keys
4. **Implement key rotation procedures** for production environments
5. **Set up CI/CD integration** for automated deployments
6. **Create backup procedures** for age keys
7. **Document your secret management procedures** for team members
8. **Test disaster recovery** procedures with key restoration

## Additional Resources

- [SOPS Documentation](https://github.com/getsops/sops)
- [Age Encryption](https://github.com/FiloSottile/age)
- [Ansible SOPS Collection](https://docs.ansible.com/ansible/latest/collections/community/sops/)
- [Ansible Vault vs SOPS](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
