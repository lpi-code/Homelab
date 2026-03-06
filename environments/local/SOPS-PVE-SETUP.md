# SOPS setup for local PVE secrets

This guide gets you from zero to an encrypted `99-secrets.sops.yaml` for the local Proxmox VE host so Ansible can use `root_password`, `proxmox_user`, and `proxmox_password` without storing them in plain text.

## Prerequisites

- **sops** and **age** on your machine
- **Ansible collection** `community.sops` (repo already uses it)

### Install sops and age (Linux)

```bash
# Fedora / RHEL
sudo dnf install sops age

# Debian / Ubuntu
sudo apt install sops age

# Or from GitHub (sops)
# https://github.com/getsops/sops/releases
# https://github.com/FiloSottile/age/releases
```

### Ensure Ansible has the SOPS collection

```bash
ansible-galaxy collection install -r shared/requirements/requirements.yaml
```

## Option A: You already have the repo’s age key

If someone gave you the private key that matches the key in `shared/configs/sops.yaml`:

1. Create the key directory and put the key there:

   ```bash
   mkdir -p ~/.config/sops/age
   # Paste the private key (AGE-SECRET-KEY-1...) into that file
   nano ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

2. Skip to [Create and encrypt the secrets file](#create-and-encrypt-the-secrets-file).

## Option B: Use your own age key (recommended for local only)

1. Generate a new age key:

   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

2. Get your public key:

   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Example output: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. Add your public key to the SOPS config so new files are encrypted for you.

   Edit **`shared/configs/sops.yaml`** and add your key to the `age` list for the `.sops.` rule:

   ```yaml
   creation_rules:
     - path_regex: 'secrets\.(yaml|yml|json|env)$'
       age:
         - "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"
         - "age1YOUR_PUBLIC_KEY_HERE"   # your key
     - path_regex: '.*\.sops\.(yaml|yml|json)$'
       age:
         - "age1r6q7uzp4qmgg8w53pdzmncg5yhmx5smse49ehwjuwys3q2njtu2qkwqwg6"
         - "age1YOUR_PUBLIC_KEY_HERE"   # your key
   ```

   (If the config currently has `age: "single_key"`, change it to `age: ["single_key", "your_key"]`.)

## Create and encrypt the secrets file

1. Go to the PVE host vars directory:

   ```bash
   cd /home/lpi/git/Homelab/environments/local/ansible/host_vars/pve02
   ```

2. Create the secrets file from the example and edit it:

   ```bash
   cp 99-secrets.sops.yaml.example 99-secrets.sops.yaml
   nano 99-secrets.sops.yaml
   ```

   Set real values (no placeholders):

   - **root_password**: root password for the PVE host (e.g. after changing from default `vagrant`).
   - **proxmox_user**: e.g. `automation`.
   - **proxmox_password**: strong password for that API user.
   - **proxmox_role_name**: e.g. `AutomationRole`.

3. Encrypt it with SOPS (from the same directory):

   ```bash
   sops --config ../../../../shared/configs/sops.yaml --encrypt -i 99-secrets.sops.yaml
   ```

   Or from repo root:

   ```bash
   cd /home/lpi/git/Homelab
   sops --config shared/configs/sops.yaml --encrypt -i environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml
   ```

4. Confirm it’s encrypted:

   ```bash
   head -5 99-secrets.sops.yaml
   # You should see sops: ... and encrypted content, not plain YAML.
   ```

5. Commit the encrypted file (do **not** commit the decrypted content):

   ```bash
   git add environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml
   git commit -m "Add encrypted PVE secrets for local environment"
   ```

## Edit secrets later

Open the encrypted file in place; SOPS will decrypt for editing and re-encrypt on save:

```bash
cd /home/lpi/git/Homelab/environments/local/ansible/host_vars/pve02
sops 99-secrets.sops.yaml
```

If SOPS doesn’t find the config automatically:

```bash
SOPS_CONFIG_PATH=/home/lpi/git/Homelab/shared/configs/sops.yaml sops 99-secrets.sops.yaml
```

## Verify Ansible sees the secrets

Ansible loads `99-secrets.sops.yaml` via the `community.sops.sops` vars plugin (see `shared/configs/ansible.cfg`). It uses `~/.config/sops/age/keys.txt` to decrypt.

Quick check (from repo root, with inventory that includes `pve02`):

```bash
cd /home/lpi/git/Homelab
ansible -i environments/local/ansible/inventory pve02 -m debug -a "var=proxmox_user"
# Should print your proxmox_user, not undefined.
```

## Troubleshooting

| Problem | What to do |
|--------|------------|
| `sops: command not found` | Install `sops` (and `age`) as in Prerequisites. |
| `no key could decrypt` | Ensure the private key for one of the `age` keys in `shared/configs/sops.yaml` is in `~/.config/sops/age/keys.txt`. |
| `no matching creation rules` | Run `sops` from repo root or pass `--config shared/configs/sops.yaml` and use the path `environments/local/ansible/host_vars/pve02/99-secrets.sops.yaml`. |
| Ansible vars `proxmox_user` / `root_password` undefined | Ensure `community.sops.sops` is in `vars_plugins_enabled` in the ansible.cfg you use, and that `99-secrets.sops.yaml` is in `host_vars/pve02/` and is encrypted (not a plain YAML copy). |

For more (key rotation, multiple keys, CI), see **`docs/gitops/SOPS_SETUP.md`**.
