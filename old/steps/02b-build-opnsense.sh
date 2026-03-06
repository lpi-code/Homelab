#!/usr/bin/env bash
# STEP: 02b
# TITLE: Build OPNsense VM template
# DESCRIPTION: Runs Packer locally to build the OPNsense VM template on PVE.
#              Skipped automatically if the template already exists (reads 02a output).
# TOOL: bash
# REQUIRES: 02a
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- Load environment ---
if [[ -z "${SHARED_DIR_PATH:-}" ]]; then
  echo "ERROR: SHARED_DIR_PATH is not set. Source environments/local/.envrc first." >&2
  exit 1
fi

OUTPUTS_DIR="${OUTPUTS_DIR:-${REPO_ROOT}/environments/local/outputs}"
PREV_OUTPUT="${OUTPUTS_DIR}/02a-templates.json"

if [[ ! -f "${PREV_OUTPUT}" ]]; then
  echo "ERROR: ${PREV_OUTPUT} not found. Run 02a-prepare-templates.ansible.yml first." >&2
  exit 1
fi

# --- Read outputs from 02a ---
_json() { python3 -c "import sys,json; d=json.load(open('${PREV_OUTPUT}')); print(d.get('$1',''))" ; }
PVE_HOST="$(_json pve_host)"
OPNSENSE_TEMPLATE_EXISTS="$(_json opnsense_template_exists)"
OPNSENSE_TEMPLATE_VM_ID="$(_json opnsense_template_vm_id)"
OPNSENSE_ISO_NAME="$(_json opnsense_iso_name)"

if [[ "${OPNSENSE_TEMPLATE_EXISTS}" == "true" ]]; then
  echo "OPNsense template VM ${OPNSENSE_TEMPLATE_VM_ID} already exists on ${PVE_HOST}, skipping Packer build."
  exit 0
fi

# --- Load PVE credentials from ansible-inventory (single source of truth) ---
if [[ -z "${ANSIBLE_INVENTORY:-}" ]]; then
  echo "ERROR: ANSIBLE_INVENTORY is not set." >&2
  exit 1
fi

echo "Loading PVE credentials from ansible-inventory..."
PVE_VARS=$(ansible-inventory --host pve02 -i "${ANSIBLE_INVENTORY}" 2>/dev/null)
PVE_USER=$(echo "${PVE_VARS}"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxmox_user','root'))")
PVE_PASSWORD=$(echo "${PVE_VARS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxmox_password',''))")
PVE_NODE=$(echo "${PVE_VARS}"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxmox_node','pve02'))")
STORAGE_POOL=$(echo "${PVE_VARS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxmox_default_storage_pool','storage-vms'))")
ISO_POOL=$(echo "${PVE_VARS}"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('proxmox_default_iso_pool','storage-isos'))")
VM_BRIDGE=$(echo "${PVE_VARS}"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('vm_network','vmbr0'))")
OPNSENSE_VERSION=$(echo "${PVE_VARS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('opnsense_version','26.1'))")

if [[ -z "${PVE_PASSWORD}" ]]; then
  echo "ERROR: Could not retrieve proxmox_password from ansible-inventory." >&2
  echo "       Check that SOPS is configured and the secrets file is decryptable." >&2
  exit 1
fi

PACKER_DIR="${SHARED_DIR_PATH}/packer/opnsense"

if [[ ! -d "${PACKER_DIR}" ]]; then
  echo "ERROR: Packer directory not found: ${PACKER_DIR}" >&2
  exit 1
fi

# --- Packer init ---
echo "Initializing Packer plugins..."
packer init "${PACKER_DIR}/opnsense.pkr.hcl"

# --- Packer build ---
echo "Building OPNsense template (VM ID: ${OPNSENSE_TEMPLATE_VM_ID}) on ${PVE_NODE}..."
PACKER_LOG=1 packer build \
  -var "proxmox_url=https://${PVE_HOST}:8006/api2/json" \
  -var "proxmox_username=${PVE_USER}@pve" \
  -var "proxmox_password=${PVE_PASSWORD}" \
  -var "proxmox_node=${PVE_NODE}" \
  -var "proxmox_storage_pool=${STORAGE_POOL}" \
  -var "proxmox_iso_pool=${ISO_POOL}" \
  -var "opnsense_version=${OPNSENSE_VERSION}" \
  -var "template_vm_id=${OPNSENSE_TEMPLATE_VM_ID}" \
  -var "network_bridge=${VM_BRIDGE}" \
  "${PACKER_DIR}/opnsense.pkr.hcl"

echo "OPNsense template built successfully (VM ID: ${OPNSENSE_TEMPLATE_VM_ID})"
