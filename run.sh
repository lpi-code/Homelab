#!/usr/bin/env bash
# Global step runner — environment-aware.
#
# Dispatches each file in shared/steps/ in numeric order:
#   *.ansible.yml  → ansible-playbook
#   *.sh           → bash
#
# Usage:
#   ./run.sh <environment> [step-prefix ...]
#
#   ./run.sh local                    # run all steps for local env
#   ./run.sh local 03b                # run a single step by prefix
#   ./run.sh local 02a 02b 03a 03b    # run specific steps in order
#   ./run.sh                          # interactive: pick environment
#
# Future: this script is the backend contract for the UI — each step emits
# structured output that the UI can capture per step.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS_DIR="${REPO_ROOT}/shared/steps"
ENVS_DIR="${REPO_ROOT}/environments"

# --- Resolve environment ---
_list_envs() {
  find "${ENVS_DIR}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort
}

ENV_NAME="${1:-}"

if [[ -z "${ENV_NAME}" ]]; then
  echo "Available environments:"
  _list_envs | while read -r e; do echo "  ${e}"; done
  echo ""
  read -r -p "Environment: " ENV_NAME
fi

# Consume the first argument so remaining args are step prefixes
shift 2>/dev/null || true

ENV_DIR="${ENVS_DIR}/${ENV_NAME}"
ENVRC="${ENV_DIR}/.envrc"

if [[ ! -d "${ENV_DIR}" ]]; then
  echo "ERROR: Environment '${ENV_NAME}' not found." >&2
  echo "Available: $(_list_envs | tr '\n' ' ')" >&2
  exit 1
fi

if [[ ! -f "${ENVRC}" ]]; then
  echo "ERROR: ${ENVRC} not found." >&2
  exit 1
fi

echo "Environment: ${ENV_NAME}"

# --- Local environment: delegate to quickstart ---
if [[ "${ENV_NAME}" == "local" ]]; then
  QUICKSTART="${ENV_DIR}/quickstart.sh"
  if [[ ! -f "${QUICKSTART}" ]]; then
    echo "ERROR: ${QUICKSTART} not found." >&2
    exit 1
  fi
  bash "${QUICKSTART}" || exit $?
fi

# shellcheck disable=SC1090
source "${ENVRC}"

export OUTPUTS_DIR="${ENV_DIR}/outputs"
mkdir -p "${OUTPUTS_DIR}"

# --- Collect steps ---
ALL_STEPS=()
while IFS= read -r -d '' f; do
  ALL_STEPS+=("$f")
done < <(find "${STEPS_DIR}" -maxdepth 1 \( -name '*.ansible.yml' -o -name '*.sh' \) -print0 | sort -z)

if [[ ${#ALL_STEPS[@]} -eq 0 ]]; then
  echo "No steps found in ${STEPS_DIR}" >&2
  exit 1
fi

# Filter to requested prefixes, or run all
SELECTED_STEPS=()
if [[ $# -gt 0 ]]; then
  for prefix in "$@"; do
    found=false
    for f in "${ALL_STEPS[@]}"; do
      base="$(basename "$f")"
      if [[ "${base}" == "${prefix}"* ]]; then
        SELECTED_STEPS+=("$f")
        found=true
      fi
    done
    if ! $found; then
      echo "ERROR: No step matches prefix '${prefix}'" >&2
      echo "Available steps:" >&2
      for f in "${ALL_STEPS[@]}"; do echo "  $(basename "$f")" >&2; done
      exit 1
    fi
  done
else
  SELECTED_STEPS=("${ALL_STEPS[@]}")
fi

# --- Runner ---
_run_step() {
  local step="$1"
  local base
  base="$(basename "${step}")"

  local title description
  title=$(grep -m1 '^# TITLE:' "${step}" 2>/dev/null | sed 's/^# TITLE: *//' || echo "${base}")
  description=$(grep -m1 '^# DESCRIPTION:' "${step}" 2>/dev/null | sed 's/^# DESCRIPTION: *//' || echo "")

  echo ""
  echo "════════════════════════════════════════════════════════"
  printf "  [%s] %s\n" "${ENV_NAME}" "${base}"
  echo "  ${title}"
  [[ -n "${description}" ]] && echo "  ${description}"
  echo "════════════════════════════════════════════════════════"

  local rc=0
  case "${step}" in
    *.ansible.yml)
      ansible-playbook \
        -i "${ANSIBLE_INVENTORY}" \
        "${step}" || rc=$?
      ;;
    *.sh)
      bash "${step}" || rc=$?
      ;;
    *)
      echo "ERROR: Unknown step type: ${base}" >&2
      return 1
      ;;
  esac

  if [[ $rc -ne 0 ]]; then
    return $rc
  fi

  echo "  ✓ ${base} completed"
}

for step in "${SELECTED_STEPS[@]}"; do
  if ! _run_step "${step}"; then
    echo ""
    echo "ERROR: Step $(basename "${step}") failed." >&2
    echo "Fix the issue and re-run with:" >&2
    echo "  ./run.sh ${ENV_NAME} $(basename "${step}" | sed 's/\..*//')" >&2
    exit 1
  fi
done

echo ""
echo "════════════════════════════════════════════════════════"
echo "  All steps completed successfully. [${ENV_NAME}]"
echo "════════════════════════════════════════════════════════"
