# Reset SOPS (lost keys)

Use this when you **lost your SOPS/age keys** and cannot decrypt existing `.sops.*` files. All existing encrypted secrets will be removed and replaced by a new key; the old secrets are **not recoverable**.

## What the reset does

1. **Generates a new age key** and writes it to `~/.config/sops/age/keys.txt` (existing file is backed up with a timestamp if present).
2. **Updates `shared/configs/sops.yaml`** so the new public key is used for all SOPS creation rules.
3. **Deletes** these encrypted files (they cannot be decrypted without the old key):
   - `environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml`
   - `environments/dev/ansible/host_vars/pve02/99-secrets.sops.yaml`
   - `environments/dev/ansible/host_vars/rt-1-cluster/99-secrets.sops.yaml`
   - `environments/dev/ansible/group_vars/all/secrets.sops.yaml`

## Run the reset

From the repository root:

```bash
# Requires: age (age-keygen)
bash shared/scripts/reset-sops.sh
```

Confirm with `y` when prompted. Then recreate only the secrets files you need.

## After reset: recreate secrets

### Local environment (PVE)

You have an example file; copy, edit, then encrypt:

```bash
cd environments/local/ansible/host_vars/pve02
cp 99-secrets.sops.yaml.example 99-secrets.sops.yaml
# Edit and set: root_password, proxmox_user, proxmox_password, proxmox_role_name
nano 99-secrets.sops.yaml
sops --config ../../../../shared/configs/sops.yaml --encrypt -i 99-secrets.sops.yaml
```

See **`environments/local/SOPS-PVE-SETUP.md`** for full steps.

### Dev environment

No example files exist; create the following from scratch with real values, then encrypt.

**1. `environments/dev/ansible/host_vars/pve02/99-secrets.sops.yaml`**

```yaml
---
proxmox_user: "automation"          # or your API user
proxmox_password: "YOUR_PROXMOX_PASSWORD"
proxmox_role_name: "AutomationRole"
root_password: "YOUR_PVE_ROOT_PASSWORD"
```

**2. `environments/dev/ansible/host_vars/rt-1-cluster/99-secrets.sops.yaml`**

```yaml
---
root_password: "YOUR_ROOT_PASSWORD"   # as used by playbooks for this host
```

**3. `environments/dev/ansible/group_vars/all/secrets.sops.yaml`**

Add any shared secrets your playbooks expect in `group_vars/all` (e.g. vault passwords, API keys). Structure depends on your playbooks.

Then encrypt each file (from repo root):

```bash
sops --config shared/configs/sops.yaml --encrypt -i environments/dev/ansible/host_vars/pve02/99-secrets.sops.yaml
sops --config shared/configs/sops.yaml --encrypt -i environments/dev/ansible/host_vars/rt-1-cluster/99-secrets.sops.yaml
sops --config shared/configs/sops.yaml --encrypt -i environments/dev/ansible/group_vars/all/secrets.sops.yaml
```

## Verify

- **Decrypt test:**  
  `sops --config shared/configs/sops.yaml -d environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml`  
  should print decrypted YAML (after you recreated that file).
- **Ansible:** Run a playbook that uses those vars; they should resolve (e.g. `ansible -i environments/local/ansible/inventory pve02 -m debug -a "var=proxmox_user"`).

## See also

- **SOPS setup (normal):** `docs/gitops/SOPS_SETUP.md`
- **Local PVE secrets:** `environments/local/SOPS-PVE-SETUP.md`
