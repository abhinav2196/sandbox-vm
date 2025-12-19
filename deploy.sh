#!/bin/bash
# Fast deploy from pre-built box
set -e

BOX_FILE="signing-vm.box"
CONFIG_SSH_PORT="$(awk -F: '/^[[:space:]]*ssh_port/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' config.yaml 2>/dev/null)"
SSH_PORT="${VAGRANT_SSH_PORT:-${CONFIG_SSH_PORT:-50223}}"

# Check if box exists in vagrant (with libvirt provider)
if ! vagrant box list 2>/dev/null | grep -q "signing-vm-base.*libvirt"; then
    if [[ -f "$BOX_FILE" ]]; then
        echo "==> Adding pre-built box..."
        vagrant box add --force signing-vm-base "$BOX_FILE"
    else
        echo "Error: No pre-built box found."
        echo "Run 'make build' first to create one."
        exit 1
    fi
fi

echo "==> Destroying old VM (if any)..."
vagrant destroy -f 2>/dev/null || true
rm -rf .vagrant

echo "==> Starting fresh VM from pre-built box..."
# Note: fstab cleanup warnings during hostname set are harmless
USE_PREBUILT=1 VAGRANT_SSH_PORT="$SSH_PORT" vagrant up || {
    # Check if VM is actually running despite error
    if vagrant status 2>/dev/null | grep -q "running"; then
        echo "    (Minor warning during setup - VM is running)"
    else
        exit 1
    fi
}

echo ""
echo "==> VM ready!"
echo "    vagrant ssh"
