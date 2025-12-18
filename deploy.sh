#!/bin/bash
# Fast deploy from pre-built box
set -e

BOX_FILE="signing-vm.box"
SSH_PORT="${VAGRANT_SSH_PORT:-50222}"

# Check if box exists in vagrant
if ! vagrant box list 2>/dev/null | grep -q "signing-vm-base"; then
    if [[ -f "$BOX_FILE" ]]; then
        echo "==> Adding pre-built box..."
        vagrant box add --force signing-vm-base "$BOX_FILE"
    else
        echo "Error: No pre-built box found."
        echo "Run './build-box.sh' first to create one."
        exit 1
    fi
fi

echo "==> Destroying old VM (if any)..."
vagrant destroy -f 2>/dev/null || true
rm -rf .vagrant

echo "==> Starting fresh VM from pre-built box..."
USE_PREBUILT=1 VAGRANT_SSH_PORT="$SSH_PORT" vagrant up

echo ""
echo "==> VM ready!"
echo "    vagrant ssh"
