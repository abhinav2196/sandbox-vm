#!/bin/bash
# Harden VM so secrets + gcloud access only happen inside the encrypted secrets session.
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}==> $1${NC}"; }

info "Hardening gcloud access"

# Ensure group exists
groupadd -f gcloud >/dev/null 2>&1 || true

# Make gcloud binaries root-only (group-readable for controlled use)
for bin in /usr/bin/gcloud /usr/bin/gsutil /usr/bin/bq; do
  if [[ -f "$bin" ]]; then
    chown root:gcloud "$bin" || true
    chmod 750 "$bin" || true
  fi
done

# Ensure security user is NOT allowed to run gcloud directly
if id security >/dev/null 2>&1; then
  gpasswd -d security gcloud >/dev/null 2>&1 || true
fi

# Remove any previously persisted gcloud credentials on disk (defense-in-depth).
# With our secrets workflow, credentials should live under /mnt/secrets/gcloud only.
warn "Removing any existing gcloud credential dirs on disk (if present)"
rm -rf /root/.config/gcloud 2>/dev/null || true
rm -rf /home/security/.config/gcloud 2>/dev/null || true
rm -rf /home/vagrant/.config/gcloud 2>/dev/null || true

info "Done"

info "Removing broad sudo access (vagrant/root escalation)"

# Remove passwordless sudo for vagrant (common in base boxes).
# Goal: VM access alone should NOT imply 'sudo gcloud ...'
if id vagrant >/dev/null 2>&1; then
  deluser vagrant sudo >/dev/null 2>&1 || true
fi

# Remove common sudoers drop-ins that grant vagrant NOPASSWD
rm -f /etc/sudoers.d/vagrant 2>/dev/null || true

# cloud-init sometimes creates this file
if [[ -f /etc/sudoers.d/90-cloud-init-users ]]; then
  # Remove any vagrant lines only
  sed -i.bak '/^vagrant\s\+ALL=/d' /etc/sudoers.d/90-cloud-init-users || true
fi

# Add limited sudo for security user (only secrets.sh)
echo "security ALL=(root) NOPASSWD: /usr/local/sbin/secrets.sh" > /etc/sudoers.d/security
chmod 440 /etc/sudoers.d/security

info "Sudo is now restricted; security can only run: /usr/local/sbin/secrets.sh"


