#!/bin/bash
# Build a reusable box from provisioned VM
set -e

BOX_NAME="signing-vm.box"
BOX_DIR="$(mktemp -d)"

echo "==> Building reusable box"

# Detect provider
if [[ -d .vagrant/machines/default/qemu ]]; then
    PROVIDER="qemu"
elif [[ -d .vagrant/machines/default/virtualbox ]]; then
    PROVIDER="virtualbox"
else
    echo "Error: No VM found. Run 'vagrant up' first."
    exit 1
fi

echo "    Provider: $PROVIDER"

# Stop VM
echo "==> Stopping VM..."
vagrant halt 2>/dev/null || true

if [[ "$PROVIDER" == "qemu" ]]; then
    # QEMU: manually package the disk image
    DISK=$(find .vagrant/machines/default/qemu -name "*.img" | head -1)
    
    if [[ -z "$DISK" ]]; then
        echo "Error: No disk image found"
        exit 1
    fi
    
    echo "==> Copying disk image..."
    cp "$DISK" "$BOX_DIR/box.img"
    
    # Create metadata (qemu plugin uses libvirt provider name)
    cat > "$BOX_DIR/metadata.json" << 'EOF'
{
    "provider": "libvirt",
    "format": "qcow2",
    "virtual_size": 20
}
EOF
    
    cat > "$BOX_DIR/Vagrantfile" << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.provider "qemu" do |qe|
    qe.memory = "2048"
    qe.cpus = 2
  end
end
EOF
    
    echo "==> Creating box..."
    (cd "$BOX_DIR" && tar cvzf "$OLDPWD/$BOX_NAME" .)
    
else
    # VirtualBox: use native vagrant package
    echo "==> Packaging with vagrant..."
    vagrant package --output "$BOX_NAME"
fi

# Cleanup temp dir
rm -rf "$BOX_DIR"

# Add to vagrant
echo "==> Adding box to Vagrant..."
vagrant box add --force signing-vm-base "$BOX_NAME"

echo ""
echo "==> Done!"
echo "    Box file: $BOX_NAME ($(du -h "$BOX_NAME" | cut -f1))"
echo ""
echo "Fast deploy: ./deploy.sh"
