#!/usr/bin/env bash
# STEP: 03b
# TITLE: Deploy Talos cluster
# DESCRIPTION: Opens SSH tunnels to PVE, runs OpenTofu to provision all Talos cluster VMs,
#              then writes cluster connection details to outputs/.
# TOOL: bash
# REQUIRES: 03a
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- Validate environment ---
for var in SHARED_DIR_PATH ANSIBLE_INVENTORY; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: ${var} is not set. Source environments/local/.envrc first." >&2
    exit 1
  fi
done

OUTPUTS_DIR="${OUTPUTS_DIR:-${REPO_ROOT}/environments/local/outputs}"
TERRAFORM_DIR="${REPO_ROOT}/environments/local/terraform"
SOCKS_PORT="${SOCKS_PORT:-5801}"

# Node tunnel config — must match main.tf control_plane/worker_tunnel_ports and IPs
CONTROL_PLANE_IPS=("10.10.0.10")
CONTROL_PLANE_PORTS=(5802)
WORKER_IPS=("10.10.0.20" "10.10.0.21")
WORKER_PORTS=(5803 5804)

mkdir -p "${OUTPUTS_DIR}"

# --- Load PVE credentials from ansible-inventory (single source of truth) ---
echo "Loading PVE configuration from ansible-inventory..."
PVE_VARS=$(ansible-inventory --host pve02 -i "${ANSIBLE_INVENTORY}" 2>/dev/null)

_var() { echo "${PVE_VARS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1','$2'))" ; }

PVE_HOST=$(_var ansible_host "")
PVE_USER=$(_var proxmox_user "root")
PVE_PASSWORD=$(_var proxmox_password "")
PVE_SSH_USER=$(_var ansible_user "root")

if [[ -z "${PVE_HOST}" ]]; then
  echo "ERROR: Could not determine PVE host from ansible-inventory." >&2
  exit 1
fi
if [[ -z "${PVE_PASSWORD}" ]]; then
  echo "ERROR: Could not retrieve proxmox_password from ansible-inventory." >&2
  echo "       Check that SOPS is configured and the secrets file is decryptable." >&2
  exit 1
fi

# --- Tunnel lifecycle ---
# All tunnels are killed on exit via the PIDs collected here
TUNNEL_PIDS=()

cleanup() {
  echo "Closing SSH tunnels..."
  for pid in "${TUNNEL_PIDS[@]}"; do
    kill "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT

_open_tunnel() {
  local desc="$1" flags="$2"
  ssh -fN \
    ${flags} \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ExitOnForwardFailure=yes \
    "${PVE_SSH_USER}@${PVE_HOST}"
  # Grab the most recently started ssh matching this host
  local pid
  pid=$(pgrep -n -f "ssh.*${PVE_HOST}" || true)
  if [[ -z "${pid}" ]]; then
    echo "ERROR: Could not find PID for tunnel: ${desc}" >&2
    return 1
  fi
  TUNNEL_PIDS+=("${pid}")
  echo "  ${desc} (PID ${pid})"
}

_wait_port() {
  local port="$1" label="$2"
  for i in $(seq 1 10); do
    if nc -z 127.0.0.1 "${port}" 2>/dev/null; then return 0; fi
    sleep 1
  done
  echo "ERROR: Tunnel for ${label} on port ${port} did not become ready." >&2
  return 1
}

echo "Opening SSH tunnels..."

# SOCKS proxy — used by the bpg/proxmox provider to reach the Proxmox API
_open_tunnel "SOCKS proxy :${SOCKS_PORT} → PVE API" "-D ${SOCKS_PORT}"
_wait_port "${SOCKS_PORT}" "SOCKS proxy"

# Per-node port forwards — used by talosctl to push config and bootstrap
# Nodes are on vmbr1 (10.10.0.0/24); PVE can reach them via the bridge
for i in "${!CONTROL_PLANE_IPS[@]}"; do
  _open_tunnel "CP node ${i}: :${CONTROL_PLANE_PORTS[$i]} → ${CONTROL_PLANE_IPS[$i]}:50000" \
    "-L ${CONTROL_PLANE_PORTS[$i]}:${CONTROL_PLANE_IPS[$i]}:50000"
done

for i in "${!WORKER_IPS[@]}"; do
  _open_tunnel "Worker ${i}: :${WORKER_PORTS[$i]} → ${WORKER_IPS[$i]}:50000" \
    "-L ${WORKER_PORTS[$i]}:${WORKER_IPS[$i]}:50000"
done

# --- OpenTofu ---
cd "${TERRAFORM_DIR}"

echo "Initializing OpenTofu..."
tofu init -reconfigure -upgrade

echo "Applying cluster configuration..."
HTTPS_PROXY="socks5://127.0.0.1:${SOCKS_PORT}" \
HTTP_PROXY="socks5://127.0.0.1:${SOCKS_PORT}" \
NO_PROXY="localhost,127.0.0.1,registry.opentofu.org" \
tofu apply -auto-approve \
  -var "proxmox_host=${PVE_HOST}" \
  -var "proxmox_user=${PVE_USER}" \
  -var "proxmox_password=${PVE_PASSWORD}"
# Tunnels closed automatically by trap on EXIT

# --- Capture outputs for downstream steps ---
echo "Writing cluster outputs..."
tofu output -json > "${OUTPUTS_DIR}/03b-cluster.json"

echo ""
echo "Cluster deployed. Connection info:"
tofu output -json | python3 -c "
import sys, json
out = json.load(sys.stdin)
for k, v in out.items():
    if not v.get('sensitive', False):
        print(f'  {k}: {json.dumps(v[\"value\"])}')
" 2>/dev/null || true
