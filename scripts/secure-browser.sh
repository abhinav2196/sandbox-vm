#!/bin/bash
# Launch Firefox with profile inside the encrypted secrets mount.
# This keeps wallet extensions / seed phrases off the unencrypted VM disk.
#
# Usage (inside the secrets session, as security user):
#   secure-browser
set -e

MOUNT="/mnt/secrets"
PROFILE="$MOUNT/firefox-profile"

if [[ ! -d "$MOUNT" ]] || ! mountpoint -q "$MOUNT" 2>/dev/null; then
  echo "Error: encrypted secrets mount is not active at $MOUNT"
  echo "Run: sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml"
  exit 1
fi

mkdir -p "$PROFILE"
chmod 700 "$PROFILE"

# Allow X connections from the secrets session
xhost +local: 2>/dev/null || true

exec firefox --profile "$PROFILE" --no-remote
