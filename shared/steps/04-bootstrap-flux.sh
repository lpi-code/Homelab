#!/usr/bin/env bash
# STEP: 04
# TITLE: Bootstrap FluxCD
# DESCRIPTION: Opens an SSH tunnel to the first control plane node via PVE,
#              then runs flux bootstrap git to install FluxCD on the cluster.
#              The deploy key is read from SOPS-encrypted Ansible vars.
# TOOL: bash
# REQUIRES: 03b
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# --- Validate environment ---
for var in SHARED_DIR_PATH ANSIBLE_INVENTORY KUBECONFIG SOPS_AGE_KEY_FILE; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: ${var} is not set. Source environments/local/.envrc first." >&2
    exit 1
  fi
done

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "ERROR: KUBECONFIG file does not exist: ${KUBECONFIG}" >&2
  echo "       Run step 03b first to deploy the cluster." >&2
  exit 1
fi

if ! command -v flux &>/dev/null; then
  echo "ERROR: flux CLI is not installed." >&2
  echo "       Install it: https://fluxcd.io/flux/installation/#install-the-flux-cli" >&2
  exit 1
fi

OUTPUTS_DIR="${OUTPUTS_DIR:-${REPO_ROOT}/environments/local/outputs}"
mkdir -p "${OUTPUTS_DIR}"

# --- Load configuration from ansible-inventory (single source of truth) ---
echo "Loading configuration from ansible-inventory..."
PVE_VARS=$(ansible-inventory --host pve02 -i "${ANSIBLE_INVENTORY}" 2>/dev/null)

_var() { echo "${PVE_VARS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1','$2'))" ; }

FLUX_GIT_REPO_URL=$(_var flux_git_repo_url "")
CLUSTER_NAME=$(_var cluster_name "")
ENVIRONMENT_NAME=$(_var environment_name "")
KUBE_API_TUNNEL_PORT=$(_var kube_api_tunnel_port "5805")
PVE_HOST=$(_var ansible_host "")
PVE_SSH_USER=$(_var ansible_user "root")

# First control plane IP
CONTROL_PLANE_IP=$(echo "${PVE_VARS}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ips = d.get('control_plane_ips', [])
if ips:
    print(ips[0])
else:
    print('')
")

# Deploy key (decrypted via SOPS by ansible-inventory)
FLUX_GIT_DEPLOY_KEY=$(echo "${PVE_VARS}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('flux_git_deploy_key', ''))
")

# --- Validate loaded vars ---
for pair in \
  "flux_git_repo_url:${FLUX_GIT_REPO_URL}" \
  "cluster_name:${CLUSTER_NAME}" \
  "environment_name:${ENVIRONMENT_NAME}" \
  "ansible_host:${PVE_HOST}" \
  "control_plane_ips[0]:${CONTROL_PLANE_IP}" \
  "flux_git_deploy_key:${FLUX_GIT_DEPLOY_KEY}"; do
  name="${pair%%:*}"
  value="${pair#*:}"
  if [[ -z "${value}" ]]; then
    echo "ERROR: Could not load '${name}' from ansible-inventory." >&2
    exit 1
  fi
done

# --- Compute branch ---
if [[ "${ENVIRONMENT_NAME}" == "prod" ]]; then
  FLUX_BRANCH="main"
else
  FLUX_BRANCH="env/${ENVIRONMENT_NAME}"
fi

echo "FluxCD bootstrap configuration:"
echo "  Cluster:    ${CLUSTER_NAME}"
echo "  Environment:${ENVIRONMENT_NAME}"
echo "  Branch:     ${FLUX_BRANCH}"
echo "  Repo:       ${FLUX_GIT_REPO_URL}"
echo "  Path:       clusters/${CLUSTER_NAME}"
echo "  Tunnel:     127.0.0.1:${KUBE_API_TUNNEL_PORT} → ${CONTROL_PLANE_IP}:6443"

# --- Cleanup trap ---
TUNNEL_PID=""
TEMP_KUBECONFIG=""
TEMP_DEPLOY_KEY=""

cleanup() {
  echo "Cleaning up..."
  if [[ -n "${TUNNEL_PID}" ]]; then
    kill "${TUNNEL_PID}" 2>/dev/null || true
    echo "  SSH tunnel closed (PID ${TUNNEL_PID})"
  fi
  if [[ -n "${TEMP_KUBECONFIG}" && -f "${TEMP_KUBECONFIG}" ]]; then
    rm -f "${TEMP_KUBECONFIG}"
    echo "  Temp kubeconfig removed"
  fi
  if [[ -n "${TEMP_DEPLOY_KEY}" && -f "${TEMP_DEPLOY_KEY}" ]]; then
    rm -f "${TEMP_DEPLOY_KEY}"
    echo "  Temp deploy key removed"
  fi
}
trap cleanup EXIT

# --- SSH tunnel to kube API via PVE ---
echo "Opening SSH tunnel to Kubernetes API..."
ssh -fN \
  -L "${KUBE_API_TUNNEL_PORT}:${CONTROL_PLANE_IP}:6443" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ExitOnForwardFailure=yes \
  "${PVE_SSH_USER}@${PVE_HOST}"

TUNNEL_PID=$(pgrep -n -f "ssh.*${KUBE_API_TUNNEL_PORT}:${CONTROL_PLANE_IP}" || true)
if [[ -z "${TUNNEL_PID}" ]]; then
  echo "ERROR: Could not find PID for kube API tunnel." >&2
  exit 1
fi
echo "  Tunnel open (PID ${TUNNEL_PID})"

# Wait for tunnel to be ready
for i in $(seq 1 10); do
  if nc -z 127.0.0.1 "${KUBE_API_TUNNEL_PORT}" 2>/dev/null; then break; fi
  sleep 1
done
if ! nc -z 127.0.0.1 "${KUBE_API_TUNNEL_PORT}" 2>/dev/null; then
  echo "ERROR: Tunnel on port ${KUBE_API_TUNNEL_PORT} did not become ready." >&2
  exit 1
fi

# --- Temp kubeconfig pointing at tunnel ---
TEMP_KUBECONFIG=$(mktemp "${TMPDIR:-/tmp}/kubeconfig-flux.XXXXXX")
cp "${KUBECONFIG}" "${TEMP_KUBECONFIG}"
sed -i "s|server:.*|server: https://127.0.0.1:${KUBE_API_TUNNEL_PORT}|" "${TEMP_KUBECONFIG}"
export KUBECONFIG="${TEMP_KUBECONFIG}"

# --- Verify cluster connectivity ---
echo "Verifying cluster connectivity..."
if ! kubectl get nodes; then
  echo "ERROR: Cannot reach the cluster through the tunnel." >&2
  exit 1
fi

# --- Write deploy key to temp file ---
TEMP_DEPLOY_KEY=$(mktemp "${TMPDIR:-/tmp}/flux-deploy-key.XXXXXX")
chmod 0600 "${TEMP_DEPLOY_KEY}"
echo "${FLUX_GIT_DEPLOY_KEY}" > "${TEMP_DEPLOY_KEY}"

# --- Bootstrap FluxCD ---
echo "Bootstrapping FluxCD..."
flux bootstrap git \
  --url="${FLUX_GIT_REPO_URL}" \
  --branch="${FLUX_BRANCH}" \
  --path="clusters/${CLUSTER_NAME}" \
  --private-key-file="${TEMP_DEPLOY_KEY}" \
  --silent

# --- Verify ---
echo "Verifying FluxCD installation..."
flux check
echo ""
kubectl -n flux-system get pods

# --- Write outputs ---
cat > "${OUTPUTS_DIR}/04-flux.json" <<EOF
{
  "cluster_name": "${CLUSTER_NAME}",
  "environment_name": "${ENVIRONMENT_NAME}",
  "flux_branch": "${FLUX_BRANCH}",
  "flux_path": "clusters/${CLUSTER_NAME}",
  "flux_repo_url": "${FLUX_GIT_REPO_URL}"
}
EOF

echo ""
echo "FluxCD bootstrap complete."
echo "  Branch: ${FLUX_BRANCH}"
echo "  Path:   clusters/${CLUSTER_NAME}"
echo "  Output: ${OUTPUTS_DIR}/04-flux.json"
