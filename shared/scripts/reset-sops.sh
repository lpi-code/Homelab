#!/usr/bin/env bash
# Reset SOPS: generate new age key, update sops.yaml, remove old encrypted files.
# Use when you lost the previous key and cannot decrypt existing secrets.
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOPS_CONFIG="${REPO_ROOT}/shared/configs/sops.yaml"
OLD_KEY="age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"

# Encrypted files we will remove (cannot decrypt without old key)
ENCRYPTED_FILES=(
  "environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml"
  "environments/dev/ansible/host_vars/rt-1-cluster/99-secrets.sops.yaml"
  "environments/dev/ansible/host_vars/pve02/99-secrets.sops.yaml"
  "environments/dev/ansible/group_vars/all/secrets.sops.yaml"
)

cd "$REPO_ROOT"

echo "=== SOPS reset (you lost your keys) ==="
echo "This will:"
echo "  1. Generate a new age key and write it to ~/.config/sops/age/keys.txt"
echo "  2. Update shared/configs/sops.yaml to use the new public key"
echo "  3. Remove existing encrypted files (they are unrecoverable without the old key)"
echo ""
for f in "${ENCRYPTED_FILES[@]}"; do
  [ -f "$REPO_ROOT/$f" ] && echo "  - $f"
done
echo ""
read -r -p "Continue? [y/N] " reply
if [[ ! "${reply,,}" =~ ^y ]]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Generating new age key..."
mkdir -p ~/.config/sops/age
if [[ -f ~/.config/sops/age/keys.txt ]]; then
  echo "Backing up existing ~/.config/sops/age/keys.txt to ~/.config/sops/age/keys.txt.bak.$(date +%Y%m%d%H%M%S)"
  cp -a ~/.config/sops/age/keys.txt ~/.config/sops/age/keys.txt.bak."$(date +%Y%m%d%H%M%S)" || true
fi
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

NEW_PUBLIC=$(age-keygen -y ~/.config/sops/age/keys.txt)
echo "New public key: $NEW_PUBLIC"

echo "Updating shared/configs/sops.yaml..."
sed -i "s|$OLD_KEY|$NEW_PUBLIC|g" "$SOPS_CONFIG"
echo "Done."

echo "Removing old encrypted files..."
for f in "${ENCRYPTED_FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    rm -f "$REPO_ROOT/$f"
    echo "  removed $f"
  fi
done

echo ""
echo "=== Reset complete ==="
echo "  - New key: ~/.config/sops/age/keys.txt"
echo "  - Config:  shared/configs/sops.yaml (updated)"
echo ""
echo "Next: recreate secrets and encrypt with SOPS."
echo "  Local PVE:  environments/local/SOPS-PVE-SETUP.md"
echo "  Full doc:   docs/gitops/SOPS_SETUP.md"
echo "  Quick local: cp environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml.example \\"
echo "                 environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml"
echo "               # Edit, then: sops --config shared/configs/sops.yaml --encrypt -i environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml"
echo ""
