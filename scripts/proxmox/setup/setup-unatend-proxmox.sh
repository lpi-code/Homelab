#!/usr/bin/env bash
# nanokvm-unattended.sh
# One-stop tool to fetch latest ISO (Debian/Proxmox), make it unattended using Proxmox automated installation,
# upload to NanoKVM, optionally select ISO & control ATX power (experimental).
# 
# New features:
# - Smart power management: automatically shuts down if computer is on, then starts it
# - F11 key simulation: sends F11 key press to access boot menu and select USB device
# - Power state detection: checks LED status to determine if computer is on/off
# - macOS compatibility with Docker-based Proxmox automated installation
# - Uses official Proxmox automated installation tools via Docker
# - No manual ISO manipulation - Proxmox utility handles everything
set -euo pipefail

# ------------------ Defaults ------------------
DISTRO="proxmox"          # debian | proxmox
WORKDIR="${TMPDIR:-/tmp}/nanokvm-auto-$$"
CACHE_DIR="${HOME}/.cache/nanokvm-isos"  # ISO cache directory

# Platform detection
PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
IS_MACOS="false"
if [ "$PLATFORM" = "darwin" ]; then
  IS_MACOS="true"
fi

# Docker settings
DOCKER_PROXMOX_IMAGE="proxmox-auto-install-assistant:latest"
DOCKER_RUN="docker run --rm -v"
DOCKERFILE_PROXMOX="$(dirname "$0")/Dockerfile.proxmox"
OUT_ISO="$WORKDIR/unattended-proxmox.iso"               # optional override output path
HOSTNAME="pve"
TZ="UTC"
IFACE=""
IP_CIDR=""               # e.g. 192.0.2.10/24
GW=""
DNS="1.1.1.1"
SSH_PUBKEY="${HOME}/.ssh/id_rsa.pub"
ROOT_PASSWORD=""         # if empty, root locked; SSH key auth only
ANSWER_FILE=""           # path to custom TOML answer file (optional)
MIRROR_HTTP="http://deb.debian.org/debian"

# Disk selection
DISK_MODEL=""            # e.g. "Samsung SSD 980 PRO"
DISK_SERIAL=""           # e.g. "S5GXNX0N123456"
DISK_PATH=""             # e.g. "/dev/sda" or "/dev/nvme0n1"
DISK_SIZE=""             # e.g. "500G" or "1T"

# NanoKVM / actions
KVM_HOST=""
KVM_USER="root"
KVM_PORT="22"
AUTH_BASIC=""            # admin:password (for HTTP experimental)
SELECT_ISO="1"
POWERON="1"
POWEROFF="0"
RESET="0"
SMART_POWER="1"          # Smart power management (shutdown if on, then start)
SEND_F11="1"             # Send F11 key after mounting ISO
BOOT_KEY="F11"           # Key to press for boot menu (F11, F12, ESC, etc.)
BOOT_KEY_SEQUENCE=""     # Comma-separated sequence of keys (e.g., "F11,DOWN,ENTER")
POST_F11_SEQUENCE="DOWN,DOWN,DOWN,DOWN,DOWN,DOWN,DOWN,DOWN,DOWN,DOWN,ENTER"  # Keys to send after F11 to select boot entry
KEY_DELAY="1"            # Delay between keys in sequence (seconds)
HTTPS="0"
CURL_XTRA=""

QUIET="0"
CACHE_AGE_DAYS="7"        # Cache ISOs for 7 days by default
FORCE_DOWNLOAD="0"        # Force re-download even if cached
DEBUG_API="1"             # Enable API debugging

SKIP_BUILD="0"

bold(){ printf "\033[1m%s\033[0m\n" "$*" >&2; }
note(){ [ "$QUIET" = "1" ] || printf "👉 %s\n" "$*" >&2; }
warn(){ printf "\033[33m⚠ %s\033[0m\n" "$*" >&2; }
die(){  printf "\033[31m✖ %s\033[0m\n" "$*" >&2; exit 1; }

# List available disks and their properties for disk selection
list_available_disks(){
  note "Available disks and their properties:"
  note "Use these properties with --disk-serial, --disk-model, or --disk-path options"
  note ""
  
  # Check if we can run the Proxmox assistant
  if command -v proxmox-auto-install-assistant >/dev/null 2>&1; then
    note "Using local proxmox-auto-install-assistant:"
    proxmox-auto-install-assistant device-info -t disk 2>/dev/null | jq -r 'to_entries[] | "  \(.key): \(.value.ID_MODEL // "Unknown") - Serial: \(.value.ID_SERIAL_SHORT // "Unknown") - Size: \(.value.SIZE // "Unknown") bytes"' 2>/dev/null || true
  else
    note "Proxmox assistant not available locally, showing basic disk info:"
    lsblk -d -o NAME,MODEL,SERIAL,SIZE 2>/dev/null | grep -v "NAME" | sed 's/^/  /' || true
    note ""
    note "For detailed disk properties, install proxmox-auto-install-assistant or use Docker:"
    note "  docker run --rm --privileged -v /dev:/dev proxmox-auto-install-assistant:latest device-info -t disk"
  fi
}

usage(){
cat <<'EOF'
Usage:
  ./nanokvm-unattended.sh [--distro debian|proxmox] [--out ISO]
     [--hostname FQDN] [--timezone TZ]
     [--iface IFACE --ip A.B.C.D/NN --gw A.B.C.1 --dns 1.1.1.1]
     [--ssh-pubkey PATH] [--root-pass PASS] [--answer-file PATH]
     [--disk-model MODEL] [--disk-serial SERIAL] [--disk-path PATH] [--disk-size SIZE]
     --kvm HOST [--kvm-user root] [--kvm-port 22]
     [--auth admin:pass] [--select] [--poweron|--poweroff|--reset]
     [--smart-power] [--send-f11] [--no-f11] [--boot-key KEY] [--boot-sequence KEYS]
     [--post-f11-sequence KEYS] [--key-delay SECONDS] [--list-keys] [--list-disks] [--https] [--curl-extra "..."] [--quiet]
     [--cache-dir DIR] [--cache-age DAYS] [--force-download] [--debug-api]

Examples:
  Debian (recommended): unattended Debian that installs Proxmox in late_command,
  then upload+select+reset on NanoKVM with smart power management and F11 boot:
    ./nanokvm-unattended.sh --distro debian --kvm 10.0.0.50 --auth admin:pass --select --smart-power --send-f11 \
       --hostname pve01.example.com --timezone "Asia/Singapore" \
       --iface eno1 --ip 192.0.2.10/24 --gw 192.0.2.1 --dns 1.1.1.1 \
       --ssh-pubkey ~/.ssh/id_ed25519.pub

  Proxmox ISO (Docker-based automated installation) with smart power and F11:
    ./nanokvm-unattended.sh --distro proxmox --kvm 10.0.0.50 --auth admin:pass --select --smart-power --send-f11

  macOS with Proxmox automated installation (requires Docker Desktop):
    ./nanokvm-unattended.sh --distro proxmox --kvm 10.0.0.50 --auth admin:pass --select --smart-power \
       --hostname pve01 --iface eno1 --ip 192.168.1.100/24 --ssh-pubkey ~/.ssh/id_ed25519.pub

  Custom boot key sequence (F11, then arrow down, then enter):
    ./nanokvm-unattended.sh --distro debian --kvm 10.0.0.50 --auth admin:pass \
       --boot-sequence "F11,DOWN,ENTER" --key-delay 2

  Use F12 instead of F11 for boot menu:
    ./nanokvm-unattended.sh --distro debian --kvm 10.0.0.50 --auth admin:pass --boot-key F12

  Custom post-F11 boot sequence (default: UP,ENTER):
    ./nanokvm-unattended.sh --distro debian --kvm 10.0.0.50 --auth admin:pass --send-f11 \
       --post-f11-sequence "DOWN,DOWN,ENTER"

  With custom cache settings:
    ./nanokvm-unattended.sh --distro debian --cache-dir /tmp/my-cache --cache-age 3 --kvm 10.0.0.50

  Force re-download (ignore cache):
    ./nanokvm-unattended.sh --distro debian --force-download --kvm 10.0.0.50

  With custom TOML answer file:
    ./nanokvm-unattended.sh --distro proxmox --answer-file /path/to/my-answer.toml --kvm 10.0.0.50

  Note: NanoKVM will be automatically rebooted via SSH after checking file existence for a clean state.

  With disk selection by serial number and smart power management:
    ./nanokvm-unattended.sh --distro proxmox --kvm 10.0.0.50 \
       --disk-serial "9DU0A02D0L33" \
       --hostname pve01 --iface eno1 --ip 192.168.1.100/24 \
       --smart-power --send-f11

  With disk selection by model and size:
    ./nanokvm-unattended.sh --distro proxmox --kvm 10.0.0.50 \
       --disk-model "Samsung SSD 980 PRO" --disk-size "1T" \
       --hostname pve01 --iface eno1 --ip 192.168.1.100/24 \
       --smart-power --send-f11

  Disable F11 key sending (manual boot device selection):
    ./nanokvm-unattended.sh --distro debian --kvm 10.0.0.50 --no-f11

  List available keys for keystroke simulation:
    ./nanokvm-unattended.sh --list-keys

  List available disks and their properties for disk selection:
    ./nanokvm-unattended.sh --list-disks
EOF
}

# --------------- Argparse ---------------
while [ "${1:-}" != "" ]; do
  case "$1" in
    --distro) DISTRO="${2:?}"; shift 2;;
    --out) OUT_ISO="${2:?}"; shift 2;;
    --hostname) HOSTNAME="${2:?}"; shift 2;;
    --timezone) TZ="${2:?}"; shift 2;;
    --iface) IFACE="${2:?}"; shift 2;;
    --ip) IP_CIDR="${2:?}"; shift 2;;
    --gw) GW="${2:?}"; shift 2;;
    --dns) DNS="${2:?}"; shift 2;;
    --ssh-pubkey) SSH_PUBKEY="${2:?}"; shift 2;;
    --root-pass) ROOT_PASSWORD="${2:?}"; shift 2;;
    --answer-file) ANSWER_FILE="${2:?}"; shift 2;;
    --disk-model) DISK_MODEL="${2:?}"; shift 2;;
    --disk-serial) DISK_SERIAL="${2:?}"; shift 2;;
    --disk-path) DISK_PATH="${2:?}"; shift 2;;
    --disk-size) DISK_SIZE="${2:?}"; shift 2;;
    --kvm) KVM_HOST="${2:?}"; shift 2;;
    --kvm-user) KVM_USER="${2:?}"; shift 2;;
    --kvm-port) KVM_PORT="${2:?}"; shift 2;;
    --auth) AUTH_BASIC="${2:?}"; shift 2;;
    --select) SELECT_ISO="1"; shift 1;;
    --poweron) POWERON="1"; shift 1;;
    --poweroff) POWEROFF="1"; shift 1;;
    --reset) RESET="1"; shift 1;;
    --smart-power) SMART_POWER="1"; shift 1;;
    --send-f11) SEND_F11="1"; shift 1;;
    --no-f11) SEND_F11="0"; shift 1;;
    --boot-key) BOOT_KEY="${2:?}"; shift 2;;
    --boot-sequence) BOOT_KEY_SEQUENCE="${2:?}"; shift 2;;
    --post-f11-sequence) POST_F11_SEQUENCE="${2:?}"; shift 2;;
    --key-delay) KEY_DELAY="${2:?}"; shift 2;;
    --list-keys) list_available_keys; exit 0;;
    --list-disks) list_available_disks; exit 0;;
    --https) HTTPS="1"; shift 1;;
    --curl-extra) CURL_XTRA="${2:-}"; shift 2;;
    --cache-dir) CACHE_DIR="${2:?}"; shift 2;;
    --cache-age) CACHE_AGE_DAYS="${2:?}"; shift 2;;
    --force-download) FORCE_DOWNLOAD="1"; shift 1;;
    --debug-api) DEBUG_API="1"; shift 1;;
    --quiet) QUIET="1"; shift 1;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option $1";;
  esac
done

# --------------- Checks ---------------
# Check required tools (only basic tools needed, everything else runs in Docker)
for c in curl ssh rsync docker; do command -v "$c" >/dev/null || die "$c required"; done

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  die "Docker is not running. Please start Docker Desktop (macOS) or Docker service (Linux)."
fi

# Check if Dockerfile exists
if [[ ! -f "$DOCKERFILE_PROXMOX" ]]; then
  die "Dockerfile for Proxmox not found: $DOCKERFILE_PROXMOX"
fi
mkdir -p "$WORKDIR"
mkdir -p "$CACHE_DIR"
cleanup(){ 
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# --------------- Common helpers ---------------
progress_dl(){ # url dest
  local url="$1" dest="$2"
  note "⬇️  Downloading: $url"
  curl -L --fail --progress-bar "$url" -o "$dest"
}

# --------------- Docker Functions ---------------
# Build Proxmox assistant Docker image from external Dockerfile
build_proxmox_docker_image(){
  note "🐳 Building Proxmox auto-install assistant Docker image..."
  note "🐳 Using Dockerfile: $DOCKERFILE_PROXMOX"
  
  # Show build context
  if [ "$DEBUG_API" = "1" ]; then
    note "🔍 Build context directory: $(dirname "$DOCKERFILE_PROXMOX")"
    note "🔍 Dockerfile contents:"
    cat "$DOCKERFILE_PROXMOX" | sed 's/^/  /'
  fi
  
  if docker build -t "$DOCKER_PROXMOX_IMAGE" -f "$DOCKERFILE_PROXMOX" "$(dirname "$DOCKERFILE_PROXMOX")" >/dev/null 2>&1; then
    note "✅ Proxmox Docker image built successfully"
  else
    warn "Docker build failed, showing build output:"
    docker build -t "$DOCKER_PROXMOX_IMAGE" -f "$DOCKERFILE_PROXMOX" "$(dirname "$DOCKERFILE_PROXMOX")" || true
    die "Failed to build Proxmox Docker image from $DOCKERFILE_PROXMOX"
  fi
}

# Ensure Docker image is available
ensure_docker_image(){
  # Check if Proxmox image exists
  if ! docker image inspect "$DOCKER_PROXMOX_IMAGE" >/dev/null 2>&1; then
    build_proxmox_docker_image
  fi
  
  # Skip testing in non-debug mode to avoid hanging
  if [ "$DEBUG_API" = "1" ]; then
    note "🧪 Testing Proxmox assistant..."
    local test_output
    test_output="$(timeout 10 run_proxmox_assistant --help 2>&1 || true)"
    
    if echo "$test_output" | grep -q "Usage\|proxmox-auto-install-assistant"; then
      note "✅ Proxmox assistant is working correctly"
      note "🔍 Assistant help output:"
      echo "$test_output" | sed 's/^/  /'
    else
      warn "Proxmox assistant test failed, rebuilding image..."
      warn "Test output: $test_output"
      build_proxmox_docker_image
    fi
  else
    note "✅ Proxmox Docker image ready"
  fi
}

# Run Proxmox assistant via Docker
run_proxmox_assistant(){
  local args=("$@")
  local workdir_abs
  workdir_abs="$(cd "$WORKDIR" && pwd)"
  
  # Ensure Docker image is available
  ensure_docker_image
  
  # Debug: List files in workdir before running
  if [ "$DEBUG_API" = "1" ]; then
    note "🔍 Files in workdir before Docker run:"
    ls -la "$workdir_abs" | sed 's/^/  /'
  fi
  
  # Run the assistant with volume mounts
  note "🐳 Running Proxmox assistant with args: ${args[*]}"
  note "🐳 Workdir: $workdir_abs"
  
  # Debug: Run debug script first
  if [ "$DEBUG_API" = "1" ]; then
    note "🔍 Running debug script in container..."
    $DOCKER_RUN "$workdir_abs:/work" -w /work "$DOCKER_PROXMOX_IMAGE" -c "debug-files.sh" || true
  fi
  
  if timeout 300 $DOCKER_RUN "$workdir_abs:/work" -w /work "$DOCKER_PROXMOX_IMAGE" -c "proxmox-auto-install-assistant ${args[*]}"; then
    return 0
  else
    warn "Docker command failed with args: ${args[*]}"
    # Debug: List files in workdir after failure
    if [ "$DEBUG_API" = "1" ]; then
      note "🔍 Files in workdir after Docker failure:"
      ls -la "$workdir_abs" | sed 's/^/  /'
    fi
    return 1
  fi
}

# Generate TOML answer file for Proxmox
generate_proxmox_answer_file(){
  local answer_file="$1"
  
  # Use custom answer file if provided
  if [ -n "$ANSWER_FILE" ]; then
    if [ -f "$ANSWER_FILE" ]; then
      note "📝 Using custom answer file: $ANSWER_FILE"
      cp "$ANSWER_FILE" "$answer_file"
      
      # Validate the custom answer file
      note "🔍 Validating custom answer file..."
      if run_proxmox_assistant validate-answer "$(basename "$answer_file")" >/dev/null 2>&1; then
        note "✅ Custom answer file is valid"
      else
        warn "⚠️  Custom answer file validation failed, but proceeding anyway"
        warn "⚠️  Make sure your TOML file follows the Proxmox answer file format"
      fi
      return 0
    else
      die "Custom answer file not found: $ANSWER_FILE"
    fi
  fi
  
  note "📝 Generating Proxmox answer file: $answer_file"
  
  cat > "$answer_file" << ANSWER_EOF
# Proxmox VE Automated Installation Answer File
# Generated by nanokvm-unattended.sh

[global]
country = "us"
keyboard = "en-us"
fqdn = "${HOSTNAME%.*}.local"
mailto = "root@${HOSTNAME%.*}.local"
timezone = "${TZ}"
ANSWER_EOF

  # Add root password (required by Proxmox assistant)
  if [ -n "$ROOT_PASSWORD" ]; then
    if [ ${#ROOT_PASSWORD} -lt 8 ]; then
      warn "Root password is too short (minimum 8 characters), using default"
      echo "root-password = \"Proxmox123\"" >> "$answer_file"
    else
      echo "root-password = \"${ROOT_PASSWORD}\"" >> "$answer_file"
    fi
  else
    # Use default password if none provided
    warn "No root password provided, using default: Proxmox123"
    echo "root-password = \"Proxmox123\"" >> "$answer_file"
  fi

  # Add SSH key if provided
  if [ -f "$SSH_PUBKEY" ]; then
    local ssh_key_content
    ssh_key_content="$(cat "$SSH_PUBKEY")"
    cat >> "$answer_file" << ANSWER_EOF
root-ssh-keys = [
    "${ssh_key_content}"
]
ANSWER_EOF
  fi

  # Add network configuration
  if [ -n "$IP_CIDR" ] && [ -n "$IFACE" ]; then
    cat >> "$answer_file" << ANSWER_EOF

[network]
source = "from-answer"
cidr = "${IP_CIDR}"
gateway = "${GW}"
dns = "${DNS}"
filter = "INTERFACE==${IFACE}"
ANSWER_EOF
  else
    cat >> "$answer_file" << ANSWER_EOF

[network]
source = "from-dhcp"
ANSWER_EOF
  fi

  # Add disk setup configuration
  cat >> "$answer_file" << ANSWER_EOF

[disk-setup]
filesystem = "ext4"
ANSWER_EOF

  if [ -n "$DISK_PATH" ]; then
    # Use specific disk path
    local disk_name
    disk_name="$(basename "$DISK_PATH")"
    cat >> "$answer_file" << ANSWER_EOF
disk-list = ["${disk_name}"]
ANSWER_EOF
  elif [ -n "$DISK_MODEL" ] || [ -n "$DISK_SERIAL" ] || [ -n "$DISK_SIZE" ]; then
    # Add disk filters using proper TOML format
    cat >> "$answer_file" << ANSWER_EOF
filter-match = "any"
ANSWER_EOF
    
    # Add individual filter properties
    if [ -n "$DISK_MODEL" ]; then
      cat >> "$answer_file" << ANSWER_EOF
filter.ID_MODEL = "${DISK_MODEL}"
ANSWER_EOF
    fi
    
    if [ -n "$DISK_SERIAL" ]; then
      cat >> "$answer_file" << ANSWER_EOF
filter.ID_SERIAL_SHORT = "${DISK_SERIAL}"
ANSWER_EOF
    fi
    
    if [ -n "$DISK_SIZE" ]; then
      # Convert size to bytes for comparison
      local size_bytes
      case "$DISK_SIZE" in
        *G) size_bytes=$((1024*1024*1024*${DISK_SIZE%G})) ;;
        *T) size_bytes=$((1024*1024*1024*1024*${DISK_SIZE%T})) ;;
        *) size_bytes=$((1024*1024*1024*${DISK_SIZE})) ;; # Assume GB
      esac
      cat >> "$answer_file" << ANSWER_EOF
filter.SIZE = ">=${size_bytes}"
ANSWER_EOF
    fi
  else
    cat >> "$answer_file" << ANSWER_EOF
disk-list = ["sda"]
ANSWER_EOF
  fi

  note "✅ Answer file generated successfully"
}

# Validate TOML answer file
validate_proxmox_answer_file(){
  local answer_file="$1"
  
  if [[ ! -f "$answer_file" ]]; then
    die "Answer file not found: $answer_file"
  fi
  
  # Basic TOML validation (check for required sections)
  local required_sections=("global" "network" "disk")
  for section in "${required_sections[@]}"; do
    if ! grep -q "^\[$section\]" "$answer_file"; then
      warn "Missing required section: [$section]"
    fi
  done
  
  # Check for required global settings
  if ! grep -q "^fqdn" "$answer_file"; then
    warn "Missing fqdn in global section"
  fi
  
  if ! grep -q "^timezone" "$answer_file"; then
    warn "Missing timezone in global section"
  fi
  
  note "✅ Answer file validation completed"
}

# Cache management functions
is_cache_valid(){ # file_path
  local file="$1"
  [ -f "$file" ] || return 1
  [ "$FORCE_DOWNLOAD" = "1" ] && return 1
  
  local age_days
  age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
  [ "$age_days" -lt "$CACHE_AGE_DAYS" ]
}

get_cached_iso(){ # url filename
  local url="$1" filename="$2"
  local cached_file="${CACHE_DIR}/${filename}"
  
  if is_cache_valid "$cached_file"; then
    note "📁 Using cached ISO: $filename"
    cp "$cached_file" "${WORKDIR}/${filename}"
    return 0
  fi
  
  if [ -f "$cached_file" ]; then
    note "🗑️  Cached ISO expired, re-downloading: $filename"
    rm -f "$cached_file"
  fi
  
  return 1
}

cache_iso(){ # local_file filename
  local local_file="$1" filename="$2"
  local cached_file="${CACHE_DIR}/${filename}"
  
  if [ -f "$local_file" ]; then
    note "💾 Caching ISO: $filename"
    cp "$local_file" "$cached_file"
  fi
}

cleanup_cache(){
  local cache_dir="$1"
  local age_days="${2:-7}"
  
  if [ -d "$cache_dir" ]; then
    note "🧹 Cleaning cache older than $age_days days"
    find "$cache_dir" -name "*.iso" -type f -mtime "+${age_days}" -delete 2>/dev/null || true
  fi
}

# Disk selection functions
generate_disk_preseed(){
  local preseed_file="$1"
  
  # If no disk criteria specified, use default
  if [ -z "$DISK_MODEL" ] && [ -z "$DISK_SERIAL" ] && [ -z "$DISK_PATH" ] && [ -z "$DISK_SIZE" ]; then
    echo "d-i partman-auto/disk string /dev/sda" >> "$preseed_file"
    return 0
  fi
  
  # Generate disk selection preseed
  cat >> "$preseed_file" << 'DISK_PRESEED'
# Disk selection preseed
d-i partman/early_command string \
  DEBIAN_FRONTEND=noninteractive debconf-set-selections << 'EOF'
DISK_PRESEED

  # Add disk selection logic based on available criteria
  if [ -n "$DISK_MODEL" ] || [ -n "$DISK_SERIAL" ] || [ -n "$DISK_SIZE" ]; then
    cat >> "$preseed_file" << 'DISK_LOGIC'
  # Find disk by model, serial, or size
  for disk in /sys/block/*/device; do
    if [ -e "$disk" ]; then
      devname=$(basename $(dirname $disk))
      # Skip loop devices and partitions
      case "$devname" in
        loop*|ram*|fd*) continue ;;
      esac
      
      # Check model if specified
      if [ -n "$DISK_MODEL" ]; then
        if ! grep -q "$DISK_MODEL" /sys/block/$devname/device/model 2>/dev/null; then
          continue
        fi
      fi
      
      # Check serial if specified
      if [ -n "$DISK_SERIAL" ]; then
        if ! grep -q "$DISK_SERIAL" /sys/block/$devname/device/serial 2>/dev/null; then
          continue
        fi
      fi
      
      # Check size if specified
      if [ -n "$DISK_SIZE" ]; then
        size_bytes=$(cat /sys/block/$devname/size 2>/dev/null || echo 0)
        size_bytes=$((size_bytes * 512))
        case "$DISK_SIZE" in
          *G) expected_size=$((1024*1024*1024*${DISK_SIZE%G})) ;;
          *T) expected_size=$((1024*1024*1024*1024*${DISK_SIZE%T})) ;;
          *) expected_size=$((1024*1024*1024*${DISK_SIZE})) ;; # Assume GB
        esac
        if [ $size_bytes -lt $expected_size ]; then
          continue
        fi
      fi
      
      # Found matching disk
      echo "partman-auto/disk string /dev/$devname" >> /var/lib/debconf/answers
      break
    fi
  done
EOF
DISK_LOGIC
  fi
  
  # If specific path is provided, use it directly
  if [ -n "$DISK_PATH" ]; then
    echo "d-i partman-auto/disk string $DISK_PATH" >> "$preseed_file"
  fi
  
  cat >> "$preseed_file" << 'DISK_END'
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm_write_new_label boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
DISK_END
}

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

# Check if file exists on NanoKVM device
check_remote_file_exists(){
  local filename="$1"
  ssh -p "$KVM_PORT" "${KVM_USER}@${KVM_HOST}" "test -f /data/$filename" 2>/dev/null
}

# Ask user for confirmation
ask_overwrite(){
  local filename="$1"
  echo -n "File '$filename' already exists on NanoKVM. Overwrite? [y/N]: " >&2
  read -r response
  case "$response" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# NanoKVM upload / HTTP (experimental) ------------------------
upload_iso(){
  local iso="$1" base; base="$(basename "$iso")"
  
  # Check if file already exists on remote
  if [ "$SKIP_BUILD" = "1" ]; then
    note "⏭️  Skipping upload - file already exists" >&2
    return 0
  fi
  
  note "🚚 Uploading '$iso' to 'NanoKVM:/data/$base'" >&2
  ssh -p "$KVM_PORT" "${KVM_USER}@${KVM_HOST}" "mkdir -p /data && test -w /data"
  scp -P "$KVM_PORT" "$iso" "${KVM_USER}@${KVM_HOST}:/data/$base"
  echo "$base"
}

# Helper function to check if API response indicates success
is_api_success(){
  local response="$1"
  [ -n "$response" ] && echo "$response" | jq -e '.code == 0' >/dev/null 2>&1
}

# NanoKVM API authentication using proper encryption
api_login(){
  local cj; cj="$(mktemp)"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  
  # Extract username and password from AUTH_BASIC (format: "username:password")
  local username password
  username="${AUTH_BASIC%%:*}"
  password="${AUTH_BASIC#*:}"
  
  # NanoKVM hardcoded secret key
  local PWSECKEY="nanokvm-sipeed-2024"
  
  note "🔐 Attempting NanoKVM login for user: $username"
  
  # Encrypt password using AES-256-CBC with the correct method
  local PASSENC
  PASSENC=$(echo -n "$password" | openssl enc -aes-256-cbc -base64 -salt -md md5 -pass pass:"$PWSECKEY" 2>/dev/null)
  
  if [ -z "$PASSENC" ]; then
    warn "❌ Password encryption failed" >&2
    rm -f "$cj"; echo ""; return 1
  fi
  
  # Build JSON string for login with URL encoding
  local AUTHJSON
  AUTHJSON=$(jq -crnM --arg u "$username" --arg p "$PASSENC" '{"username":$u|@uri,"password":$p|@uri}')
  
  # Send login request
  local response
  response=$(curl -s -X POST "${base}/api/auth/login" \
    -H 'Content-Type: application/json' \
    --data-raw "$AUTHJSON" $CURL_XTRA)
  
  # Check if login was successful and extract token
  local token
  token=$(echo "$response" | jq -r '.data.token // empty' 2>/dev/null)
  
  if [ -n "$token" ] && [ "$token" != "null" ]; then
    # Store cookie variable in the file for other functions to use
    echo "nano-kvm-token=$token" > "$cj"
    note "✅ Login successful, token received"
    echo "$cj"; return 0
  else
    # Try fallback methods if token-based auth fails
    note "🔄 Token auth failed, trying fallback methods..."
    
    # Fallback: Try with plain password
    AUTHJSON=$(jq -crnM --arg u "$username" --arg p "$password" '{"username":$u|@uri,"password":$p|@uri}')
    response=$(curl -s -X POST "${base}/api/auth/login" \
      -H 'Content-Type: application/json' \
      --data-raw "$AUTHJSON" $CURL_XTRA)
    
    token=$(echo "$response" | jq -r '.data.token // empty' 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
      echo "nano-kvm-token=$token" > "$cj"
      note "✅ Login successful via fallback method"
      echo "$cj"; return 0
    fi
    
    # Final fallback: Basic auth
    if curl -fsS -c "$cj" -u "$AUTH_BASIC" $CURL_XTRA \
      -X POST "${base}/api/auth/login" >/dev/null 2>&1; then
      note "✅ Login successful via Basic Auth fallback"
      echo "$cj"; return 0
    fi
  fi
  
  warn "❌ All login methods failed for NanoKVM" >&2
  warn "Response: $response" >&2
  rm -f "$cj"; echo ""; return 1
}

api_get_device_info(){
  local cookie="$1"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  local COOKIE; COOKIE="$(cat "$cookie" 2>/dev/null || echo "")"
  local response
  response=$(curl -s -b "$COOKIE" $CURL_XTRA "${base}/api/vm/info" 2>/dev/null)
  
  # Check if response is valid and code is 0
  if is_api_success "$response"; then
    echo "$response"
  else
    if [ "$DEBUG_API" = "1" ]; then
      note "🔍 Device Info API debug - Cookie: $COOKIE"
      note "🔍 Device Info API debug - Response: $response"
      note "🔍 Device Info API debug - Curl command: curl -s -b '$COOKIE' $CURL_XTRA '${base}/api/vm/info'"
    fi
    echo '{"code":-1,"msg":"error","data":{"ip":"","mdns":"","image":"","firmware":"","deviceKey":""}}'
  fi
}

api_get_led_status(){
  local cookie="$1"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  local COOKIE; COOKIE="$(cat "$cookie" 2>/dev/null || echo "")"
  local response
  response=$(curl -s -b "$COOKIE" $CURL_XTRA "${base}/api/vm/gpio" 2>/dev/null)
  
  # Check if response is valid and code is 0
  if is_api_success "$response"; then
    echo "$response"
  else
    if [ "$DEBUG_API" = "1" ]; then
      note "🔍 LED API debug - Cookie: $COOKIE"
      note "🔍 LED API debug - Response: $response"
      note "🔍 LED API debug - Curl command: curl -s -b '$COOKIE' $CURL_XTRA '${base}/api/vm/gpio'"
    fi
    echo '{"code":-1,"msg":"error","data":{"pwr":false,"hdd":false}}'
  fi
}

api_get_mounted_image(){
  local cookie="$1"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  local COOKIE; COOKIE="$(cat "$cookie" 2>/dev/null || echo "")"
  local response
  response=$(curl -s -b "$COOKIE" $CURL_XTRA "${base}/api/storage/image/mounted" 2>/dev/null)
  
  # Check if response is valid and code is 0
  if is_api_success "$response"; then
    echo "$response"
  else
    if [ "$DEBUG_API" = "1" ]; then
      note "🔍 Mounted Image API debug - Cookie: $COOKIE"
      note "🔍 Mounted Image API debug - Response: $response"
      note "🔍 Mounted Image API debug - Curl command: curl -s -b '$COOKIE' $CURL_XTRA '${base}/api/storage/image/mounted'"
    fi
    echo '{"code":-1,"msg":"error","data":{"file":""}}'
  fi
}

api_select_iso(){
  local cookie="$1" name="$2"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  local COOKIE; COOKIE="$(cat "$cookie" 2>/dev/null || echo "")"
  
  # Build JSON with URL encoding
  local body
  body='{"file":"/data/'"$name"'"}'
 

  # Try the correct API endpoints based on NanoKVM documentation
  for ep in /api/storage/image/mount /api/usb/iso/select /api/iso/select /api/usb/select; do
    local response
    response=$(curl -s -b "$COOKIE" -H "Content-Type: application/json" $CURL_XTRA \
      -X POST -d "$body" "${base}${ep}" 2>/dev/null)
    
    # Check if the response indicates success (code must be 0)
    if is_api_success "$response"; then
      note "🖱️  ISO selected via ${ep}"
      return 0
    else
      if [ "$DEBUG_API" = "1" ]; then
        note "🔍 ISO Select API debug - Body: $body"
        note "🔍 ISO Select API debug - Endpoint: ${ep}"
        note "🔍 ISO Select API debug - Response: $response"
        note "🔍 ISO Select API debug - Cookie: $COOKIE"
      fi
    fi
  done
  warn "Could not select ISO via HTTP; select in NanoKVM UI as fallback."
  return 1
}

api_atx(){
  local cookie="$1" action="$2"; local scheme="http"; [ "$HTTPS" = "1" ] && scheme="https"
  local base="${scheme}://${KVM_HOST}"
  local COOKIE; COOKIE="$(cat "$cookie" 2>/dev/null || echo "")"
  
  # Build JSON with URL encoding
  local body
  body=$(jq -crnM '{"type":"power","duration":800}')
  
  # Use correct NanoKVM GPIO API endpoint: /api/vm/gpio
  local response
  response=$(curl -s -b "$COOKIE" -H "Content-Type: application/json" $CURL_XTRA \
    -X POST -d "$body" "${base}/api/vm/gpio" 2>/dev/null)
  
  # Check if the response indicates success (code must be 0)
  if [ -n "$response" ] && echo "$response" | jq -e '.code == 0' >/dev/null 2>&1; then
    note "⚡ Power button pressed via /api/vm/gpio"
    return 0
  fi
  
  warn "ATX power control failed via HTTP."
  if [ "$DEBUG_API" = "1" ]; then
    note "🔍 ATX API debug - Response: $response"
    note "🔍 ATX API debug - Cookie: $COOKIE"
  else
    warn "Response: $response"
  fi
  return 1
}

# Key mapping for USB HID simulation
declare -A KEY_MAP=(
  ["F11"]="0x44"
  ["F12"]="0x45"
  ["F1"]="0x3A"
  ["F2"]="0x3B"
  ["F3"]="0x3C"
  ["F4"]="0x3D"
  ["F5"]="0x3E"
  ["F6"]="0x3F"
  ["F7"]="0x40"
  ["F8"]="0x41"
  ["F9"]="0x42"
  ["F10"]="0x43"
  ["ESC"]="0x29"
  ["ENTER"]="0x28"
  ["SPACE"]="0x2C"
  ["TAB"]="0x2B"
  ["UP"]="0x52"
  ["DOWN"]="0x51"
  ["LEFT"]="0x50"
  ["RIGHT"]="0x4F"
  ["HOME"]="0x4A"
  ["END"]="0x4D"
  ["PAGEUP"]="0x4B"
  ["PAGEDOWN"]="0x4E"
  ["DEL"]="0x4C"
  ["BACKSPACE"]="0x2A"
  ["CTRL"]="0xE0"
  ["ALT"]="0xE2"
  ["SHIFT"]="0xE1"
)

# Send keystroke via SSH using USB HID device
send_keystroke_ssh(){
  local key="$1"
  local duration="${2:-1}"  # Duration to hold key in seconds
  
  note "⌨️  Sending key '$key' via SSH USB HID simulation"
  
  # Get key code from mapping
  local key_code="${KEY_MAP[$key]}"
  if [ -z "$key_code" ]; then
    warn "❌ Unknown key: $key. Available keys: ${!KEY_MAP[*]}"
    return 1
  fi
  
  # Convert hex to decimal for easier handling
  local key_decimal
  key_decimal=$((key_code))
  key_code=${key_code#0}
  
  # Send key press via SSH
  if ssh -p "$KVM_PORT" "${KVM_USER}@${KVM_HOST}" \
    "echo -ne \\\\x00\\\\x00\\\\$key_code\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00 > /dev/hidg0"; then
    # Show the command that was executed
    note "✅ Key '$key' pressed successfull (decimal: $key_decimal, key_code: $key_code)"
    note "✅ Command: echo -ne \\\\x00\\\\x00\\\\$key_code\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00 > /dev/hidg0"
  else
    warn "❌ Failed to send key '$key' via SSH"
    return 1
  fi
}

# Send multiple keystrokes in sequence
send_keystroke_sequence(){
  local keys="$1"
  local delay="${2:-1}"  # Delay between keys in seconds
  
  note "⌨️  Sending keystroke sequence: $keys"
  
  IFS=',' read -ra KEY_ARRAY <<< "$keys"
  for key in "${KEY_ARRAY[@]}"; do
    key=$(echo "$key" | xargs)  # Trim whitespace
    if ! send_keystroke_ssh "$key" 0; then
      warn "⚠️  Failed to send key '$key' in sequence"
      return 1
    fi
    if [ "$delay" -gt 0 ]; then
      sleep "$delay"
    fi
  done
  
  note "✅ Keystroke sequence completed"
  return 0
}

# List available keys for debugging
list_available_keys(){
  note "Available keys for keystroke simulation:"
  for key in "${!KEY_MAP[@]}"; do
    printf "  %-10s (0x%s)\n" "$key" "${KEY_MAP[$key]#0x}"
  done
}

# Legacy function for backward compatibility
api_send_f11(){
  send_keystroke_ssh "F11" 1
}

# Check if computer is powered on by checking LED status
is_computer_on(){
  local cookie="$1"
  local led_status; led_status="$(api_get_led_status "$cookie")"
  
  if is_api_success "$led_status"; then
    local pwr_led; pwr_led="$(echo "$led_status" | jq -r '.data.pwr // false' 2>/dev/null || echo "false")"
    [ "$pwr_led" = "true" ]
  else
    # If we can't determine status, assume it's off to be safe
    false
  fi
}

# Smart power management: shutdown if on, then start
smart_power_cycle(){
  local cookie="$1"
  
  if is_computer_on "$cookie"; then
    note "🔄 Computer is on, shutting down first..."
    if api_atx "$cookie" poweroff; then
      note "⏳ Waiting for shutdown to complete (30 seconds)..."
      sleep 30
    else
      warn "⚠️  Shutdown command failed, proceeding anyway..."
    fi
  fi
  
  note "🚀 Starting computer..."
  if api_atx "$cookie" poweron; then
    note "⏳ Waiting for boot to begin (1 seconds)..."
    sleep 1
    return 0
  else
    warn "❌ Failed to start computer"
    return 1
  fi
}

# --------------- Debian unattended builder (robust) ---------------
build_debian_unattended(){
  bold "🔎 Finding latest Debian netinst (amd64, stable)"
  local base="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"
  local list="${WORKDIR}/index.html"
  progress_dl "$base/" "$list"
  local iso url
  iso="$(grep -oE 'debian-[0-9.]+-amd64-netinst\.iso' "$list" | sort -V | tail -n1)"
  [ -n "$iso" ] || die "Could not find Debian netinst ISO on index"
  url="${base}/${iso}"
  local in_iso="${WORKDIR}/${iso}"
  
  # Try to use cached ISO first
  if ! get_cached_iso "$url" "$iso"; then
    progress_dl "$url" "$in_iso"
    cache_iso "$in_iso" "$iso"
  fi

  # Optional checksum
  if grep -q "SHA256SUMS" "$list"; then
    progress_dl "${base}/SHA256SUMS" "${WORKDIR}/SHA256SUMS"
    local sum; sum="$(grep " ${iso}$" "${WORKDIR}/SHA256SUMS" | awk '{print $1}')"
    if [ -n "$sum" ]; then echo "${sum}  ${in_iso}" | shasum -a 256 -c - || warn "Checksum mismatch" >&2; fi
  fi

  bold "🧬 Making it unattended using Proxmox assistant"
  
  # Generate TOML answer file for Proxmox (which will install Debian + Proxmox)
  local answer_file="${WORKDIR}/answer.toml"
  generate_proxmox_answer_file "$answer_file"
  
  # Validate the answer file
  validate_proxmox_answer_file "$answer_file"
  
  # Show the generated answer file for debugging
  if [ "$DEBUG_API" = "1" ]; then
    note "📄 Generated answer file content:"
    cat "$answer_file" | sed 's/^/  /'
  fi
  
  # Use Proxmox assistant to prepare ISO (it will handle Debian installation + Proxmox)
  local out="$OUT_ISO"
  note "🐳 Using Proxmox assistant to prepare Debian ISO with Proxmox installation..."
  note "📋 Command: prepare-iso $(basename "$in_iso") --fetch-from iso --answer-file answer.toml --output $(basename "$out")"
  
  if run_proxmox_assistant prepare-iso "$(basename "$in_iso")" --fetch-from iso --answer-file answer.toml --output "$(basename "$out")"; then
    # Move the output file to the expected location
    if [ -f "${WORKDIR}/$(basename "$out")" ]; then
      mv "${WORKDIR}/$(basename "$out")" "$out"
      note "✅ Debian ISO prepared successfully with Proxmox installation"
    else
      die "Failed to find prepared ISO output"
    fi
  else
    die "Failed to prepare Debian ISO with Proxmox assistant"
  fi
  
  echo "$out"
}

# --------------- Proxmox unattended builder (Docker-based) ---------------
build_proxmox_unattended(){
  bold "🔎 Finding latest Proxmox VE ISO (web page scrape)"
  local index="${WORKDIR}/pve.html"
  progress_dl "https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso" "$index"
  local slug; slug="$(grep -oE 'proxmox-ve-[0-9.-]+-iso-installer' "$index" | head -n1)"
  [ -n "$slug" ] || die "Could not find PVE ISO slug"
  local page="${WORKDIR}/pve-iso.html"
  progress_dl "https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso/${slug}" "$page"
  local iso_url; iso_url="$(grep -oE 'https?://[^"]+\.iso' "$page" | head -n1)"
  [ -n "$iso_url" ] || die "Could not extract direct ISO URL"
  
  # Extract filename from URL for caching
  local iso_filename; iso_filename="$(basename "$iso_url")"
  local in_iso="${WORKDIR}/${iso_filename}"
  
  # Try to use cached ISO first
  if ! get_cached_iso "$iso_url" "$iso_filename"; then
    progress_dl "$iso_url" "$in_iso"
    cache_iso "$in_iso" "$iso_filename"
  fi

  bold "🧬 Making PVE ISO unattended using Docker-based Proxmox assistant"
  
  # Generate TOML answer file
  local answer_file="${WORKDIR}/answer.toml"
  generate_proxmox_answer_file "$answer_file"
  
  # Validate the answer file
  validate_proxmox_answer_file "$answer_file"
  
  # Show the generated answer file for debugging
  if [ "$DEBUG_API" = "1" ]; then
    note "📄 Generated answer file content:"
    cat "$answer_file" | sed 's/^/  /'
  fi
  
  # Use Docker-based Proxmox assistant to prepare ISO
  local out="$OUT_ISO"
  note "🐳 Using Docker to prepare Proxmox ISO with answer file..."
  note "📋 Command: prepare-iso $(basename "$in_iso") --fetch-from iso --answer-file answer.toml --output $(basename "$out")"
  
  if run_proxmox_assistant prepare-iso "$(basename "$in_iso")" --fetch-from iso --answer-file answer.toml --output "$(basename "$out")"; then
    # Move the output file to the expected location
    if [ -f "${WORKDIR}/$(basename "$out")" ]; then
      mv "${WORKDIR}/$(basename "$out")" "$out"
      note "✅ Proxmox ISO prepared successfully with automated installation"
    else
      die "Failed to find prepared ISO output"
    fi
  else
    die "Failed to prepare Proxmox ISO with assistant"
  fi
  
  echo "$out"
}


# --------------- Build ---------------
bold "🚧 Working dir: $WORKDIR"
bold "📁 Cache dir: $CACHE_DIR"
bold "🖥️  Platform: $PLATFORM $(if [ "$IS_MACOS" = "true" ]; then echo "(macOS)"; else echo "(Linux)"; fi)"

# Clean up old cache files
cleanup_cache "$CACHE_DIR" "$CACHE_AGE_DAYS"

# Check if file already exists on NanoKVM before building
SKIP_BUILD="0"

FINAL_ISO=""
if [ "$SKIP_BUILD" = "0" ]; then
  case "$DISTRO" in
    debian)  FINAL_ISO="$(build_debian_unattended)";;
    proxmox) FINAL_ISO="$(build_proxmox_unattended)";;
    *) die "Unknown --distro $DISTRO";;
  esac
  bold "✅ Built ISO: $OUT_ISO"
fi

# --------------- Upload & (optional) control NanoKVM ---------------
if [ -n "$KVM_HOST" ]; then
  # Always reboot NanoKVM after checking file existence for clean state
  expected_filename="$(basename "$OUT_ISO")"
  if check_remote_file_exists "$expected_filename"; then
    if ask_overwrite "$expected_filename"; then
      note "🔄 Will overwrite existing file after building new ISO" >&2
    else
      note "⏭️  Skipping build and upload - file already exists" >&2
      SKIP_BUILD="1"
      SELNAME="$expected_filename"
    fi
  fi
  note "🔄 Rebooting NanoKVM for clean state..."
  if ssh -p "$KVM_PORT" "${KVM_USER}@${KVM_HOST}" "reboot" 2>/dev/null; then
    note "✅ NanoKVM reboot command sent successfully"
    note "⏳ Waiting for NanoKVM to come back online (30 seconds)..."
    sleep 30
  else
    warn "⚠️  Failed to reboot NanoKVM via SSH"
    warn "⚠️  You may need to manually reboot the NanoKVM device"
  fi
  if [ "$SKIP_BUILD" = "0" ]; then
    upload_iso "$OUT_ISO"
  fi
  SELNAME="$(basename "$OUT_ISO")"
  if [ -n "$AUTH_BASIC" ]; then
    CJ="$(api_login || true)"
    if [ -n "${CJ:-}" ]; then
      # Get device information
      DEVICE_INFO="$(api_get_device_info "$CJ")"
      LED_STATUS="$(api_get_led_status "$CJ")"
      
      # Parse device info for display (only if API call was successful)
      if is_api_success "$DEVICE_INFO"; then
        DEVICE_IP="$(echo "$DEVICE_INFO" | jq -r '.data.ip // "unknown"' 2>/dev/null || echo "unknown")"
        DEVICE_FIRMWARE="$(echo "$DEVICE_INFO" | jq -r '.data.firmware // "unknown"' 2>/dev/null || echo "unknown")"
        DEVICE_IMAGE="$(echo "$DEVICE_INFO" | jq -r '.data.image // "none"' 2>/dev/null || echo "none")"
        note "📊 NanoKVM Device Info: IP=$DEVICE_IP, Firmware=$DEVICE_FIRMWARE, Current Image=$DEVICE_IMAGE"
      else
        warn "⚠️  Failed to get device info from NanoKVM"
      fi
      
      # Parse LED status (only if API call was successful)
      if is_api_success "$LED_STATUS"; then
        LED_PWR="$(echo "$LED_STATUS" | jq -r '.data.pwr // false' 2>/dev/null || echo "false")"
        LED_HDD="$(echo "$LED_STATUS" | jq -r '.data.hdd // false' 2>/dev/null || echo "false")"
        note "📊 NanoKVM LED Status: Power=$LED_PWR, HDD=$LED_HDD"
      else
        warn "⚠️  Failed to get LED status from NanoKVM"
      fi
      
      # Mount the ISO image
      if [ "$SELECT_ISO" = "1" ]; then
        if api_select_iso "$CJ" "$SELNAME"; then
          note "📀 Successfully mounted ISO: $SELNAME"
        else
          warn "⚠️  Failed to mount ISO: $SELNAME"
        fi
      fi
      
      # Smart power management: shutdown if on, then start
      if [ "$SMART_POWER" = "1" ]; then
        if smart_power_cycle "$CJ"; then
          note "✅ Smart power cycle completed"
        else
          warn "⚠️  Smart power cycle failed, trying manual power control"
          [ "$POWERON" = "1" ] && api_atx "$CJ" poweron || true
        fi
      else
        # Manual power control (legacy behavior)
        [ "$POWERON" = "1" ] && api_atx "$CJ" poweron || true
        [ "$POWEROFF" = "1" ] && api_atx "$CJ" poweroff || true
        [ "$RESET" = "1" ] && api_atx "$CJ" reset || true
      fi
      
      # Send keystrokes to access boot menu and select USB
      if [ "$SEND_F11" = "1" ]; then
        note "⏳ Waiting for boot process to begin (1 seconds)..."
        sleep 0
        
        # Use key sequence if specified, otherwise use single boot key with repetition
        if [ -n "$BOOT_KEY_SEQUENCE" ]; then
          if send_keystroke_sequence "$BOOT_KEY_SEQUENCE" "$KEY_DELAY"; then
            note "✅ Boot key sequence sent - should access boot menu and select USB"
            note "💡 The system should now boot from the mounted USB ISO"
          else
            warn "⚠️  Failed to send boot key sequence - you may need to manually select boot device"
          fi
        else
          # Send F11 key every 1 second for 10 times
          note "⌨️  Sending $BOOT_KEY key every 1 second for 10 times..."
          success_count=0
          for i in {1..10}; do
            if send_keystroke_ssh "$BOOT_KEY" 1; then
              success_count=$((success_count + 1))
              note "✅ $BOOT_KEY key sent ($i/10)"
            else
              warn "⚠️  Failed to send $BOOT_KEY key ($i/10)"
            fi
            if [ $i -lt 10 ]; then
              sleep 0
            fi
          done
          
          if [ $success_count -gt 0 ]; then
            note "✅ $BOOT_KEY key sent $success_count/10 times - should access boot menu"
            
            # Send post-F11 boot sequence to select the right boot entry
            if [ -n "$POST_F11_SEQUENCE" ]; then
              note "⏳ Waiting for boot menu to appear (20 seconds)..."
              sleep 20
              note "⌨️  Sending post-F11 boot sequence: $POST_F11_SEQUENCE"
              if send_keystroke_sequence "$POST_F11_SEQUENCE" "$KEY_DELAY"; then
                note "✅ Boot sequence sent - should select correct boot entry"
                note "💡 The system should now boot from the mounted USB ISO"
              else
                warn "⚠️  Failed to send boot sequence - you may need to manually select boot device"
              fi
            else
              note "💡 The system should now boot from the mounted USB ISO"
            fi
          else
            warn "⚠️  Failed to send $BOOT_KEY key - you may need to manually select boot device"
          fi
        fi
      fi
      rm -f "$CJ" || true
    else
      warn "NanoKVM login failed; skipping select/power ops."
    fi
  else
    [ "$SELECT_ISO" = "1" ] && warn "Pass --auth admin:pass to auto-select ISO"
  fi
fi

bold "🎉 Done."
