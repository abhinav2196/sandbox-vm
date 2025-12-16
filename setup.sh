#!/bin/bash
# Install prerequisites for Secure Signing VM
set -e

echo "==> Detecting platform"

# Platform detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_ARM=$([[ $(uname -m) == "arm64" ]] && echo 1 || echo 0)
    
    # Install Homebrew if missing
    command -v brew &>/dev/null || {
        echo "==> Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    }
    
    # Install Vagrant
    command -v vagrant &>/dev/null || {
        echo "==> Installing Vagrant"
        brew install vagrant
    }
    
    # Install provider
    if [[ $IS_ARM -eq 1 ]]; then
        command -v qemu-system-aarch64 &>/dev/null || {
            echo "==> Installing QEMU"
            brew install qemu
        }
        vagrant plugin list | grep -q vagrant-qemu || {
            echo "==> Installing vagrant-qemu plugin"
            vagrant plugin install vagrant-qemu
        }
        echo "export VAGRANT_DEFAULT_PROVIDER=qemu" >> ~/.zshrc 2>/dev/null || true
    else
        command -v vboxmanage &>/dev/null || {
            echo "==> Installing VirtualBox"
            brew install --cask virtualbox
        }
    fi
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    command -v vagrant &>/dev/null || sudo apt-get install -y vagrant
    command -v vboxmanage &>/dev/null || sudo apt-get install -y virtualbox
fi

echo "==> Setup complete"
echo ""
echo "Next: cp config.example config.yaml && vagrant up"
