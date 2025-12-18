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
SIZE_MB=128

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

die() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}==> $1${NC}"; }

# Check config exists
[[ -f "$CONFIG" ]] || die "Config not found: $CONFIG"

# Parse secrets from YAML (simple parser - no deps)
parse_secrets() {
    grep -A2 "^\s*-\s*label:" "$CONFIG" | grep -E "label:|project:" | \
    paste - - | sed 's/.*label:\s*\(\S*\).*project:\s*\(\S*\).*/\2:\1/'
}

# Create encrypted volume
create_encrypted_volume() {
    info "Creating encrypted volume"
    
    [[ $EUID -eq 0 ]] || die "Must run as root"
    
    # Prompt for password (never stored)
    echo -e "${YELLOW}Enter encryption password (will NOT be stored):${NC}"
    read -s ENC_PASS
    echo
    echo -e "${YELLOW}Confirm password:${NC}"
    read -s ENC_PASS2
    echo
    [[ "$ENC_PASS" == "$ENC_PASS2" ]] || die "Passwords don't match"
    
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
    
    unset ENC_PASS ENC_PASS2
    info "Encrypted volume ready at $MOUNT"
}

# Authenticate with GCP
gcp_auth() {
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
        SECRET_PATH="projects/$project/secrets/$label/versions/latest"
        
        if DATA=$(gcloud secrets versions access "$SECRET_PATH" 2>/dev/null); then
            echo "$DATA" > "$MOUNT/$label.json"
            chmod 600 "$MOUNT/$label.json"
            info "Saved: $MOUNT/$label.json"
        else
            warn "Failed to fetch: $label"
        fi
    done < <(parse_secrets)
}

# Cleanup on exit
cleanup() {
    info "Cleaning up encrypted volume"
    umount "$MOUNT" 2>/dev/null || true
    cryptsetup close secrets 2>/dev/null || true
    rm -f /dev/shm/secrets-backing
    info "Secrets destroyed"
}

# Main
case "$CMD" in
  fetch)
    create_encrypted_volume
    fetch_secrets
    echo -e "\n${GREEN}Secrets ready at $MOUNT${NC}"
    echo "Type 'exit' or Ctrl+D to destroy secrets"
    trap cleanup EXIT
    su - security -c "cd $MOUNT && bash"
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

