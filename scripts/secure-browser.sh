#!/bin/bash
# Launch a browser profile inside the encrypted secrets mount.
# This prevents wallet extensions / seed phrases from landing on the unencrypted VM disk.
#
# Usage (inside the secrets session, as security user):
#   secure-browser.sh
#
set -e

MOUNT="/mnt/secrets"
PROFILE="$MOUNT/browser-profile"

if [[ ! -d "$MOUNT" ]] || ! mountpoint -q "$MOUNT" 2>/dev/null; then
  echo "Error: encrypted secrets mount is not active at $MOUNT"
  echo "Run: sudo /vagrant_config/scripts/secrets.sh  (and enter the password)"
  exit 1
fi

mkdir -p "$PROFILE"
chmod 700 "$PROFILE" || true

if command -v chromium-browser >/dev/null 2>&1; then
  exec chromium-browser --user-data-dir="$PROFILE" --no-first-run --disable-sync
fi

if command -v chromium >/dev/null 2>&1; then
  exec chromium --user-data-dir="$PROFILE" --no-first-run --disable-sync
fi

echo "Error: chromium not installed"
exit 1



