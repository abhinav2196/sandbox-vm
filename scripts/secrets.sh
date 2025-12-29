#!/bin/bash
# Fetch GCP secrets and store in encrypted volume
# Usage:
#   secrets.sh                          # fetch using /vagrant_config/config.yaml
#   secrets.sh /path/to/config.yaml     # fetch using provided config
#   secrets.sh fetch [/path/to/config]  # explicit fetch
#   secrets.sh cleanup                  # cleanup mount + mapper (best-effort)
set -e

DEFAULT_CONFIG="/vagrant_config/config.yaml"
CMD="${1:-fetch}"
CONFIG="${2:-$DEFAULT_CONFIG}"

# Back-compat: if first arg is a file path, treat it as CONFIG and default to fetch
if [[ -f "${1:-}" ]]; then
  CMD="fetch"
  CONFIG="$1"
fi

MOUNT="/mnt/secrets"
SIZE_MB=512

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

die() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}==> $1${NC}"; }

# Make sure gcloud credentials never persist outside the encrypted mount.
# gcloud stores tokens under $CLOUDSDK_CONFIG; we point it into $MOUNT after mount.
gcloud_in_mount() {
  export CLOUDSDK_CONFIG="$MOUNT/gcloud"
  mkdir -p "$CLOUDSDK_CONFIG"
  chmod 700 "$CLOUDSDK_CONFIG"
}

# Check config exists
[[ -f "$CONFIG" ]] || die "Config not found: $CONFIG"

# Parse secrets from YAML (project:label format)
parse_secrets() {
    grep -A2 "^\s*-\s*label:" "$CONFIG" | grep -E "label:|project:" | \
    paste - - | sed 's/.*label:\s*\(\S*\).*project:\s*\(\S*\).*/\2:\1/'
}

# Clean up any existing encrypted volume resources
cleanup_existing() {
    # Unmount if mounted
    if mountpoint -q "$MOUNT" 2>/dev/null; then
        warn "Unmounting existing mount at $MOUNT"
        umount "$MOUNT" 2>/dev/null || umount -l "$MOUNT" 2>/dev/null || true
    fi
    
    # Close device mapper if open
    if [[ -e /dev/mapper/secrets ]]; then
        warn "Closing existing device mapper 'secrets'"
        cryptsetup close secrets 2>/dev/null || true
    fi
    
    # Detach any loop devices using the backing file
    BACKING="/dev/shm/secrets-backing"
    if [[ -f "$BACKING" ]]; then
        for loop in $(losetup -j "$BACKING" 2>/dev/null | cut -d: -f1); do
            warn "Detaching existing loop device $loop"
            losetup -d "$loop" 2>/dev/null || true
        done
        rm -f "$BACKING"
    fi
}

# Create encrypted volume
create_encrypted_volume() {
    info "Creating encrypted volume"
    
    [[ $EUID -eq 0 ]] || die "Must run as root"
    
    # Clean up any leftover resources from previous runs
    cleanup_existing
    
    # Auto-generate random password (encryption without prompts)
    ENC_PASS=$(head -c 32 /dev/urandom | base64)
    
    # Create RAM-backed encrypted volume
    BACKING="/dev/shm/secrets-backing"
    dd if=/dev/zero of="$BACKING" bs=1M count=$SIZE_MB 2>/dev/null
    chmod 600 "$BACKING"
    
    LOOP=$(losetup -f --show "$BACKING")
    echo -n "$ENC_PASS" | cryptsetup luksFormat --batch-mode "$LOOP" -
    echo -n "$ENC_PASS" | cryptsetup open "$LOOP" secrets -
    
    mkfs.ext4 -q /dev/mapper/secrets
    mkdir -p "$MOUNT"
    mount /dev/mapper/secrets "$MOUNT"
    chmod 700 "$MOUNT"
    chown security:security "$MOUNT"
    
    unset ENC_PASS
    info "Encrypted volume ready at $MOUNT"
}

# Authenticate with GCP
gcp_auth() {
    gcloud_in_mount
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        warn "GCP authentication required"
        gcloud auth login --no-launch-browser
    fi
    info "GCP authenticated"
}

# Fetch secrets
fetch_secrets() {
    gcp_auth
    
    while IFS=: read -r project label; do
        [[ -z "$project" || -z "$label" ]] && continue
        
        info "Fetching: $project/$label"
        # Use explicit flags (less error-prone than resource-name parsing)
        if DATA=$(gcloud secrets versions access latest --secret="$label" --project="$project" 2>/dev/null); then
            echo "$DATA" > "$MOUNT/$label.json"
            chmod 600 "$MOUNT/$label.json"
            chown security:security "$MOUNT/$label.json" 2>/dev/null || true
            info "Saved: $MOUNT/$label.json"
        else
            warn "Failed to fetch: $label"
            echo ""
            echo "Debug (run inside VM):"
            echo "  gcloud secrets versions access latest --secret=\"$label\" --project=\"$project\""
            echo ""
            # Show real error for faster diagnosis
            gcloud secrets versions access latest --secret="$label" --project="$project" 2>&1 | tail -20 || true
        fi
    done < <(parse_secrets)
}

# Cleanup on exit
cleanup() {
    info "Cleaning up encrypted volume"
    
    # Unmount
    if mountpoint -q "$MOUNT" 2>/dev/null; then
        umount "$MOUNT" 2>/dev/null || umount -l "$MOUNT" 2>/dev/null || true
    fi
    
    # Close device mapper
    if [[ -e /dev/mapper/secrets ]]; then
        cryptsetup close secrets 2>/dev/null || true
    fi
    
    # Detach loop devices and remove backing file
    BACKING="/dev/shm/secrets-backing"
    if [[ -f "$BACKING" ]]; then
        for loop in $(losetup -j "$BACKING" 2>/dev/null | cut -d: -f1); do
            losetup -d "$loop" 2>/dev/null || true
        done
        rm -f "$BACKING"
    fi
    
    info "Secrets destroyed"
}

# Main
case "$CMD" in
  fetch)
    # Mount namespace isolation: other VM sessions cannot see /mnt/secrets
    if [[ "${SECRETS_UNSHARED:-}" != "1" ]] && command -v unshare >/dev/null 2>&1; then
      exec unshare -m --propagation private env SECRETS_UNSHARED=1 "$0" fetch "$CONFIG"
    fi

    create_encrypted_volume
    fetch_secrets
    echo -e "\n${GREEN}Secrets ready at $MOUNT${NC}"
    trap cleanup EXIT
    if [[ -t 0 ]]; then
      echo "Type 'exit' or Ctrl+D to destroy secrets"
      su - security -c "cd $MOUNT && bash"
    else
      echo "Non-interactive shell detected; not spawning an interactive session."
      echo "To browse files: vagrant ssh  (then: sudo ls -la $MOUNT)"
    fi
    ;;
  cleanup)
    cleanup
    ;;
  *)
    echo "Usage:"
    echo "  secrets.sh"
    echo "  secrets.sh /path/to/config.yaml"
    echo "  secrets.sh fetch [/path/to/config.yaml]"
    echo "  secrets.sh cleanup"
    exit 1
    ;;
esac

