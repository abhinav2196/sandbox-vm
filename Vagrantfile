# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================================================
# Security Sandbox Vagrantfile
# ============================================================================
#
# Designed for handling sensitive security tasks with complete isolation
#
# FEATURES:
#   - Encrypted transient shell (enc-env) with runtime-generated passwords
#   - gcloud CLI with authentication prompt on VM start
#   - Browser wallet extension provisioning (MetaMask, etc.)
#   - GCP Secret Manager integration for wallet credentials
#
# MULTI-ARCHITECTURE & MULTI-PROVIDER SUPPORT:
# This Vagrantfile supports teams with mixed hardware:
#   - Apple Silicon Mac (M1/M2/M3)  → QEMU, Parallels, or VMware
#   - Intel Mac                     → VirtualBox or VMware
#   - Linux (x86_64)                → VirtualBox or VMware
#
# IMPORTANT: Different providers use different box formats!
#   - QEMU/libvirt requires specific libvirt-compatible boxes
#   - VirtualBox/VMware/Parallels use generic Vagrant boxes
#
# The script auto-detects your platform and selects the appropriate box.
# Run './setup.sh' first to install prerequisites for your system.
#
# ============================================================================

Vagrant.configure("2") do |config|
  
  # ============================================================================
  # CONFIGURATION OPTIONS - Customize your sandbox here
  # ============================================================================
  
  # Security user configuration
  SECURITY_USER_HAS_SUDO = false  # Set to true to allow security user sudo access
  ADMIN_USER_ENABLED = true       # Set to false to disable admin user entirely
  
  # Encrypted environment configuration
  ENC_ENV_SIZE_MB = 256           # Size of encrypted RAM-based volume
  
  # Resource allocation (adjust based on your host system)
  VM_MEMORY = "2048"  # MB
  VM_CPUS = 2
  
  # ============================================================================
  # PLATFORM DETECTION
  # ============================================================================
  
  host_os = RbConfig::CONFIG['host_os']
  is_mac = host_os.include?('darwin')
  is_apple_silicon = is_mac && `uname -m`.strip == 'arm64'
  is_linux = host_os.include?('linux')
  
  # Detect provider (supports team with different architectures and providers)
  # Team members may use: QEMU (Apple Silicon), VirtualBox (Intel/Linux), VMware, Parallels
  provider = ENV['VAGRANT_DEFAULT_PROVIDER'] || 'virtualbox'
  
  # Select appropriate box based on provider and architecture
  # NOTE: Different providers require different box formats!
  if provider == 'qemu' && is_apple_silicon
    config.vm.box = "perk/ubuntu-2204-arm64"  # libvirt/QEMU ARM64 box
  elsif is_apple_silicon
    config.vm.box = "ubuntu/jammy64"  # Generic ARM64 for Parallels/VMware
  else
    config.vm.box = "ubuntu/jammy64"  # AMD64 for Intel Mac and Linux
  end
  
  config.vm.hostname = "security-sandbox"
  
  # ============================================================================
  # PROVIDER CONFIGURATIONS
  # ============================================================================
  
  # QEMU provider (FREE, best for Apple Silicon)
  # NOTE: vagrant-qemu runs headless by default. For GUI access:
  #   1. SSH into VM: vagrant ssh
  #   2. Or use UTM/QEMU manually for GUI workflow
  config.vm.provider "qemu" do |qe|
    qe.memory = VM_MEMORY
    qe.cpus = VM_CPUS
    qe.machine = "virt,accel=hvf,highmem=off"
    qe.cpu = "cortex-a72"
    qe.net_device = "virtio-net-pci"
    qe.ssh_port = 2222
    qe.arch = "aarch64" if is_apple_silicon
  end
  
  # VirtualBox provider (FREE, for Intel Mac and Linux)
  config.vm.provider "virtualbox" do |vb|
    vb.memory = VM_MEMORY
    vb.cpus = VM_CPUS
    vb.gui = true
    vb.name = "security-sandbox"
    
    # Minimal VRAM
    vb.customize ["modifyvm", :id, "--vram", "16"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    
    # SECURITY: Disable shared folders and clipboard
    vb.customize ["modifyvm", :id, "--clipboard", "disabled"]
    vb.customize ["modifyvm", :id, "--draganddrop", "disabled"]
    
    # Network isolation
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
  end
  
  # VMware provider (paid plugin, good performance)
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.gui = true
    vmware.memory = VM_MEMORY
    vmware.cpus = VM_CPUS
    vmware.vmx["vram"] = "16"
    
    # SECURITY: Disable shared folders and clipboard
    vmware.vmx["isolation.tools.copy.disable"] = "true"
    vmware.vmx["isolation.tools.paste.disable"] = "true"
    vmware.vmx["isolation.tools.dnd.disable"] = "true"
    vmware.vmx["isolation.tools.setGUIOptions.enable"] = "false"
    vmware.vmx["ethernet0.noPromisc"] = "true"
  end
  
  # Parallels provider (paid, best performance on Apple Silicon)
  config.vm.provider "parallels" do |prl|
    prl.memory = VM_MEMORY.to_i
    prl.cpus = VM_CPUS
    prl.update_guest_tools = false
    prl.name = "security-sandbox"
    
    # SECURITY: Disable shared folders and clipboard
    prl.customize ["set", :id, "--shared-clipboard", "off"]
    prl.customize ["set", :id, "--shared-profile", "off"]
    prl.customize ["set", :id, "--smart-mount", "off"]
    prl.customize ["set", :id, "--shared-cloud", "off"]
    prl.customize ["set", :id, "--time-sync", "off"]
  end
  
  # ============================================================================
  # NETWORK CONFIGURATION - Isolated by design
  # ============================================================================
  
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 22, host: 2222, id: "ssh", auto_correct: true
  
  # SECURITY: Disable default shared folder
  config.vm.synced_folder ".", "/vagrant", disabled: true
  
  # ============================================================================
  # PROVISIONING - System setup and security configuration
  # ============================================================================
  
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    
    echo "=================================================="
    echo "Security Sandbox Provisioning"
    echo "=================================================="
    
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install essential security tools
    apt-get install -y \
      git \
      gnupg2 \
      gpg-agent \
      pinentry-gtk2 \
      curl \
      wget \
      vim \
      nano \
      tree \
      htop \
      unzip \
      openssh-client \
      ca-certificates \
      pass \
      keychain \
      jq \
      cryptsetup
    
    # Install lightweight desktop environment (XFCE)
    apt-get install -y xfce4 xfce4-goodies lightdm xfce4-screensaver
    
    # ============================================================================
    # GOOGLE CLOUD CLI INSTALLATION
    # ============================================================================
    
    echo "Installing Google Cloud CLI..."
    
    # Add Google Cloud SDK repository
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
      tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
      gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    
    apt-get update
    apt-get install -y google-cloud-cli
    
    echo "✓ Google Cloud CLI installed"
    
    # ============================================================================
    # BROWSER INSTALLATION (for wallet extensions)
    # ============================================================================
    
    echo "Installing browsers for wallet extensions..."
    
    # Install Firefox ESR (stable, extension-friendly)
    apt-get install -y firefox-esr
    
    # Install Chromium (for Chrome extension compatibility)
    apt-get install -y chromium-browser || apt-get install -y chromium
    
    echo "✓ Browsers installed (Firefox ESR, Chromium)"
    
    # Configure GPG
    mkdir -p /etc/gnupg
    echo "use-agent" >> /etc/gnupg/gpg.conf
    echo "pinentry-program /usr/bin/pinentry-gtk-2" >> /etc/gnupg/gpg-agent.conf
    
    # ============================================================================
    # USER CREATION - Security and Admin users
    # ============================================================================
    
    # Create security user (primary user for sensitive operations)
    if ! id -u security >/dev/null 2>&1; then
      adduser --disabled-password --gecos "" security
      echo "security:SecurePass123!" | chpasswd

      # Add to sudo group if configured
      if [ "#{SECURITY_USER_HAS_SUDO}" = "true" ]; then
        usermod -aG sudo security
        echo "✓ Security user created WITH sudo access"
      else
        echo "✓ Security user created WITHOUT sudo access"
      fi
    fi
    
    # Create admin user (for system maintenance) if enabled
    if [ "#{ADMIN_USER_ENABLED}" = "true" ]; then
      if ! id -u admin >/dev/null 2>&1; then
        adduser --disabled-password --gecos "" admin
        echo "admin:AdminPass123!" | chpasswd
        usermod -aG sudo admin
        echo "✓ Admin user created with sudo access"
      fi
    fi
    
    # Configure auto-login for security user
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf << 'EOF'
[SeatDefaults]
autologin-user=security
autologin-user-timeout=0
EOF
    
    # ============================================================================
    # SECURITY USER ENVIRONMENT SETUP
    # ============================================================================
    
    # Create directory structure
    sudo -u security mkdir -p /home/security/{.gnupg,.ssh,keys,work,backups}
    sudo -u security chmod 700 /home/security/.gnupg
    sudo -u security chmod 700 /home/security/.ssh
    
    # Configure git
    sudo -u security git config --global init.defaultBranch main
    sudo -u security git config --global pull.rebase false
    
    # Create desktop shortcuts
    sudo -u security mkdir -p /home/security/Desktop
    cat > /home/security/Desktop/Work.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Work Directory
Exec=thunar /home/security/work
Icon=folder
Terminal=false
EOF
    chmod +x /home/security/Desktop/Work.desktop
    chown security:security /home/security/Desktop/Work.desktop
    
    # ============================================================================
    # FIREWALL CONFIGURATION - Network isolation
    # ============================================================================
    
    apt-get install -y ufw
    
    # Default deny all
    ufw --force enable
    ufw default deny incoming
    ufw default deny outgoing
    
    # Allow only essential outbound
    ufw allow out 53/udp    # DNS
    ufw allow out 80/tcp    # HTTP
    ufw allow out 443/tcp   # HTTPS
    
    echo "✓ Firewall configured (DNS, HTTP, HTTPS only)"
    
    # ============================================================================
    # ENCRYPTED TRANSIENT ENVIRONMENT (enc-env)
    # ============================================================================
    
    echo "Setting up encrypted transient environment..."
    
    # Create the enc-env script for encrypted shell sessions
    cat > /usr/local/bin/enc-env << 'ENCENV'
#!/bin/bash
# enc-env: Encrypted Transient Shell Environment
# Password is generated at runtime and never stored

set -e

ENC_SIZE_MB=${ENC_SIZE_MB:-256}
ENC_MOUNT="/mnt/enc-env"
ENC_DEVICE="/dev/mapper/enc-env"
RAMDISK="/dev/shm/enc-env-backing"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║           ENCRYPTED TRANSIENT ENVIRONMENT                 ║"
    echo "║                                                           ║"
    echo "║  • Password generated at runtime (never stored)          ║"
    echo "║  • All data encrypted with AES-256-XTS                   ║"
    echo "║  • Environment destroyed on exit                         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

cleanup() {
    echo -e "\n${YELLOW}Cleaning up encrypted environment...${NC}"
    
    # Kill any processes using the mount
    fuser -km "$ENC_MOUNT" 2>/dev/null || true
    
    # Unmount
    umount "$ENC_MOUNT" 2>/dev/null || true
    
    # Close encrypted device
    cryptsetup close enc-env 2>/dev/null || true
    
    # Destroy the RAM-backed file (overwrite with zeros first)
    if [ -f "$RAMDISK" ]; then
        dd if=/dev/zero of="$RAMDISK" bs=1M count=$ENC_SIZE_MB 2>/dev/null || true
        rm -f "$RAMDISK"
    fi
    
    # Clear environment variables
    unset ENC_PASSWORD
    unset ENC_WORK
    
    echo -e "${GREEN}✓ Encrypted environment destroyed. No traces remain.${NC}"
}

start_enc_env() {
    print_banner
    
    # Check for root (needed for cryptsetup)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Encrypted environment requires elevated privileges.${NC}"
        echo "Re-running with sudo..."
        exec sudo -E "$0" "$@"
    fi
    
    # Generate a random password (32 bytes, base64 encoded)
    ENC_PASSWORD=$(head -c 32 /dev/urandom | base64)
    
    echo -e "${GREEN}✓ Generated transient encryption password${NC}"
    echo -e "${YELLOW}  (Password exists only in memory, will be destroyed on exit)${NC}"
    echo ""
    
    # Create RAM-backed file for the encrypted volume
    echo "Creating ${ENC_SIZE_MB}MB encrypted RAM volume..."
    dd if=/dev/zero of="$RAMDISK" bs=1M count=$ENC_SIZE_MB 2>/dev/null
    chmod 600 "$RAMDISK"
    
    # Set up loop device
    LOOP_DEV=$(losetup -f --show "$RAMDISK")
    
    # Create encrypted volume with the generated password
    echo -n "$ENC_PASSWORD" | cryptsetup luksFormat --batch-mode "$LOOP_DEV" -
    echo -n "$ENC_PASSWORD" | cryptsetup open "$LOOP_DEV" enc-env -
    
    # Create filesystem
    mkfs.ext4 -q "$ENC_DEVICE"
    
    # Mount
    mkdir -p "$ENC_MOUNT"
    mount "$ENC_DEVICE" "$ENC_MOUNT"
    
    # Create work directories
    mkdir -p "$ENC_MOUNT/keys"
    mkdir -p "$ENC_MOUNT/wallets"
    mkdir -p "$ENC_MOUNT/secrets"
    mkdir -p "$ENC_MOUNT/work"
    
    # Set permissions for the calling user
    CALLING_USER=${SUDO_USER:-$USER}
    chown -R "$CALLING_USER:$CALLING_USER" "$ENC_MOUNT"
    chmod 700 "$ENC_MOUNT"
    
    echo -e "${GREEN}✓ Encrypted environment ready at: $ENC_MOUNT${NC}"
    echo ""
    echo -e "${CYAN}Directory structure:${NC}"
    echo "  $ENC_MOUNT/keys/     - Private keys"
    echo "  $ENC_MOUNT/wallets/  - Wallet data"
    echo "  $ENC_MOUNT/secrets/  - GCP secrets cache"
    echo "  $ENC_MOUNT/work/     - Working directory"
    echo ""
    echo -e "${YELLOW}Starting encrypted shell. Type 'exit' to destroy environment.${NC}"
    echo ""
    
    # Set up trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Export environment for the shell
    export ENC_WORK="$ENC_MOUNT/work"
    export ENC_KEYS="$ENC_MOUNT/keys"
    export ENC_WALLETS="$ENC_MOUNT/wallets"
    export ENC_SECRETS="$ENC_MOUNT/secrets"
    export PS1="\[\033[0;31m\][enc-env]\[\033[0m\] \u@\h:\w\$ "
    
    # Start shell as the original user
    cd "$ENC_MOUNT/work"
    su - "$CALLING_USER" -c "cd $ENC_MOUNT/work && ENC_WORK=$ENC_WORK ENC_KEYS=$ENC_KEYS ENC_WALLETS=$ENC_WALLETS ENC_SECRETS=$ENC_SECRETS PS1='[enc-env] \u@\h:\w\$ ' bash"
}

case "${1:-start}" in
    start)
        start_enc_env
        ;;
    status)
        if mountpoint -q "$ENC_MOUNT" 2>/dev/null; then
            echo -e "${GREEN}Encrypted environment is ACTIVE at $ENC_MOUNT${NC}"
            df -h "$ENC_MOUNT"
        else
            echo -e "${YELLOW}Encrypted environment is NOT active${NC}"
        fi
        ;;
    *)
        echo "Usage: enc-env [start|status]"
        exit 1
        ;;
esac
ENCENV
    
    chmod +x /usr/local/bin/enc-env
    echo "✓ Encrypted transient environment (enc-env) configured"
    
    # ============================================================================
    # PROVISION.SH - Wallet Extension Provisioning Script
    # ============================================================================
    
    cat > /usr/local/bin/provision.sh << 'PROVISION'
#!/bin/bash
# provision.sh - Provision browser wallet extensions and retrieve secrets
#
# Usage: provision.sh <wallet_type> <gcp_secret_name>
# Example: provision.sh metamask projects/myproject/secrets/my-wallet/versions/latest

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

WALLET_TYPE="${1:-}"
GCP_SECRET="${2:-}"

print_usage() {
    echo -e "${CYAN}Wallet Extension Provisioning${NC}"
    echo ""
    echo "Usage: provision.sh <wallet_type> [gcp_secret_name]"
    echo ""
    echo "Wallet Types:"
    echo "  metamask     - MetaMask browser extension"
    echo "  rabby        - Rabby Wallet extension"
    echo "  phantom      - Phantom Wallet (Solana)"
    echo ""
    echo "Examples:"
    echo "  provision.sh metamask"
    echo "  provision.sh metamask projects/myproject/secrets/wallet-seed/versions/latest"
    echo ""
    echo "GCP Secret Format (JSON):"
    echo '  {"seed_phrase": "word1 word2 ...", "password": "optional_pw"}'
}

check_gcloud_auth() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        echo -e "${YELLOW}Not authenticated with gcloud. Starting authentication...${NC}"
        gcloud auth login --no-launch-browser
    fi
}

install_metamask_firefox() {
    echo -e "${CYAN}Installing MetaMask for Firefox...${NC}"
    
    METAMASK_URL="https://addons.mozilla.org/firefox/downloads/latest/ether-metamask/latest.xpi"
    EXTENSION_DIR="$HOME/.mozilla/firefox"
    
    # Find or create Firefox profile
    PROFILE_DIR=$(find "$EXTENSION_DIR" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -1)
    
    if [ -z "$PROFILE_DIR" ]; then
        echo "Creating Firefox profile..."
        firefox-esr -CreateProfile "security" 2>/dev/null || firefox -CreateProfile "security" 2>/dev/null || true
        sleep 2
        PROFILE_DIR=$(find "$EXTENSION_DIR" -maxdepth 1 -type d -name "*.security*" 2>/dev/null | head -1)
    fi
    
    if [ -n "$PROFILE_DIR" ]; then
        mkdir -p "$PROFILE_DIR/extensions"
        curl -sL "$METAMASK_URL" -o "/tmp/metamask.xpi"
        
        # Extract extension ID and install
        EXTENSION_ID="webextension@metamask.io"
        cp "/tmp/metamask.xpi" "$PROFILE_DIR/extensions/${EXTENSION_ID}.xpi"
        rm -f "/tmp/metamask.xpi"
        
        echo -e "${GREEN}✓ MetaMask installed for Firefox${NC}"
    else
        echo -e "${YELLOW}Could not find Firefox profile. Install manually from: ${NC}"
        echo "  https://addons.mozilla.org/firefox/addon/ether-metamask/"
    fi
}

install_metamask_chromium() {
    echo -e "${CYAN}Installing MetaMask for Chromium...${NC}"
    
    EXTENSION_ID="nkbihfbeogaeaoehlefnkodbefgpgknn"
    CHROMIUM_POLICIES="/etc/chromium/policies/managed"
    
    # Create policy directory
    sudo mkdir -p "$CHROMIUM_POLICIES"
    
    # Create policy to install MetaMask
    sudo tee "$CHROMIUM_POLICIES/metamask.json" > /dev/null << POLICY
{
    "ExtensionInstallForcelist": [
        "${EXTENSION_ID};https://clients2.google.com/service/update2/crx"
    ]
}
POLICY
    
    echo -e "${GREEN}✓ MetaMask configured for Chromium (will install on next launch)${NC}"
}

install_rabby_chromium() {
    echo -e "${CYAN}Installing Rabby Wallet for Chromium...${NC}"
    
    EXTENSION_ID="acmacodkjbdgmoleebolmdjonilkdbch"
    CHROMIUM_POLICIES="/etc/chromium/policies/managed"
    
    sudo mkdir -p "$CHROMIUM_POLICIES"
    
    sudo tee "$CHROMIUM_POLICIES/rabby.json" > /dev/null << POLICY
{
    "ExtensionInstallForcelist": [
        "${EXTENSION_ID};https://clients2.google.com/service/update2/crx"
    ]
}
POLICY
    
    echo -e "${GREEN}✓ Rabby configured for Chromium${NC}"
}

install_phantom_chromium() {
    echo -e "${CYAN}Installing Phantom Wallet for Chromium...${NC}"
    
    EXTENSION_ID="bfnaelmomeimhlpmgjnjophhpkkoljpa"
    CHROMIUM_POLICIES="/etc/chromium/policies/managed"
    
    sudo mkdir -p "$CHROMIUM_POLICIES"
    
    sudo tee "$CHROMIUM_POLICIES/phantom.json" > /dev/null << POLICY
{
    "ExtensionInstallForcelist": [
        "${EXTENSION_ID};https://clients2.google.com/service/update2/crx"
    ]
}
POLICY
    
    echo -e "${GREEN}✓ Phantom configured for Chromium${NC}"
}

retrieve_gcp_secret() {
    local secret_path="$1"
    
    echo -e "${CYAN}Retrieving secret from GCP...${NC}"
    
    check_gcloud_auth
    
    # Retrieve the secret
    SECRET_DATA=$(gcloud secrets versions access "$secret_path" 2>/dev/null)
    
    if [ -z "$SECRET_DATA" ]; then
        echo -e "${RED}Failed to retrieve secret: $secret_path${NC}"
        return 1
    fi
    
    # Parse JSON secret
    SEED_PHRASE=$(echo "$SECRET_DATA" | jq -r '.seed_phrase // empty')
    PASSWORD=$(echo "$SECRET_DATA" | jq -r '.password // empty')
    
    if [ -n "$SEED_PHRASE" ]; then
        echo -e "${GREEN}✓ Secret retrieved successfully${NC}"
        
        # Store in encrypted environment if available
        if [ -n "$ENC_SECRETS" ] && [ -d "$ENC_SECRETS" ]; then
            echo "$SECRET_DATA" > "$ENC_SECRETS/wallet_secret.json"
            chmod 600 "$ENC_SECRETS/wallet_secret.json"
            echo -e "${GREEN}✓ Secret stored in encrypted environment: \$ENC_SECRETS/wallet_secret.json${NC}"
        else
            echo -e "${YELLOW}⚠ Encrypted environment not active. Run 'enc-env' first for secure storage.${NC}"
            echo ""
            echo -e "${YELLOW}Seed phrase retrieved (DISPLAY ONCE - NOT STORED):${NC}"
            echo -e "${RED}$SEED_PHRASE${NC}"
            echo ""
            if [ -n "$PASSWORD" ]; then
                echo -e "${YELLOW}Password: ${RED}$PASSWORD${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Secret retrieved but no seed_phrase found. Raw data:${NC}"
        echo "$SECRET_DATA"
    fi
}

# Main logic
case "$WALLET_TYPE" in
    metamask)
        install_metamask_firefox
        install_metamask_chromium
        if [ -n "$GCP_SECRET" ]; then
            retrieve_gcp_secret "$GCP_SECRET"
        fi
        ;;
    rabby)
        install_rabby_chromium
        if [ -n "$GCP_SECRET" ]; then
            retrieve_gcp_secret "$GCP_SECRET"
        fi
        ;;
    phantom)
        install_phantom_chromium
        if [ -n "$GCP_SECRET" ]; then
            retrieve_gcp_secret "$GCP_SECRET"
        fi
        ;;
    "")
        print_usage
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown wallet type: $WALLET_TYPE${NC}"
        print_usage
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Provisioning complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Launch browser (firefox-esr or chromium-browser)"
echo "  2. Complete wallet setup using retrieved credentials"
echo "  3. For secure operations, use 'enc-env' first"
PROVISION
    
    chmod +x /usr/local/bin/provision.sh
    echo "✓ Wallet provisioning script installed"
    
    # ============================================================================
    # SECURITY HARDENING
    # ============================================================================
    
    # Disable unnecessary services
    systemctl disable snapd 2>/dev/null || true
    systemctl disable bluetooth 2>/dev/null || true
    systemctl disable cups 2>/dev/null || true
    systemctl disable avahi-daemon 2>/dev/null || true
    
    # Configure automatic screen lock
    sudo -u security mkdir -p /home/security/.config/xfce4/xfconf/xfce-perchannel-xml
    cat > /home/security/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="idle-activation-enabled" type="bool" value="true"/>
    <property name="lock-enabled" type="bool" value="true"/>
    <property name="lock-delay" type="int" value="5"/>
  </property>
</channel>
EOF
    chown -R security:security /home/security/.config
    
    # Disable root login
    passwd -l root
    
    # ============================================================================
    # USER ENVIRONMENT - Shell configuration
    # ============================================================================
    
    cat >> /home/security/.bashrc << 'EOF'

# ============================================================================
# Security Sandbox Environment
# ============================================================================

export SANDBOX_MODE=true
export GPG_TTY=$(tty)

# Aliases
alias ll='ls -la'
alias ..='cd ..'
alias grep='grep --color=auto'

# Security functions
check_sandbox() {
    echo "=========================================="
    echo "SECURITY SANDBOX STATUS"
    echo "=========================================="
    echo "User:     $(whoami)"
    echo "Hostname: $(hostname)"
    echo "IP:       $(hostname -I | awk '{print $1}')"
    echo "Sudo:     $(groups | grep -q sudo && echo 'YES' || echo 'NO')"
    echo "gcloud:   $(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'Not authenticated')"
    echo "enc-env:  $(mountpoint -q /mnt/enc-env 2>/dev/null && echo 'ACTIVE' || echo 'Not active')"
    echo "Date:     $(date)"
    echo "=========================================="
}

secure_cleanup() {
    echo "Performing secure cleanup..."
    history -c
    rm -f ~/.bash_history
    rm -rf ~/.cache/* 2>/dev/null
    # Revoke gcloud credentials
    gcloud auth revoke --all 2>/dev/null || true
    echo "✓ Cleanup complete (including gcloud credentials)"
    echo "Remember to backup important files to ~/backups/ before destroying VM"
}

# Show status on login
if [ -f ~/SECURITY_CHECKLIST.txt ]; then
    echo ""
    echo "🔒 Security Sandbox Loaded"
    echo ""
    echo "Available commands:"
    echo "  check_sandbox    - Verify environment status"
    echo "  secure_cleanup   - Clean up before destroying VM"
    echo "  enc-env          - Start encrypted transient shell"
    echo "  provision.sh     - Provision wallet extensions"
    echo ""
fi

# ============================================================================
# GCLOUD AUTHENTICATION CHECK ON LOGIN
# ============================================================================

_check_gcloud_auth() {
    # Only prompt in interactive shells
    [[ $- != *i* ]] && return
    
    # Check if gcloud is authenticated
    local active_account=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)
    
    if [ -z "$active_account" ]; then
        echo ""
        echo -e "\033[1;33m⚠ Google Cloud CLI is not authenticated\033[0m"
        echo ""
        read -p "Would you like to authenticate now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo ""
            echo "Starting gcloud authentication..."
            echo "(Follow the URL and enter the authorization code)"
            echo ""
            gcloud auth login --no-launch-browser
        fi
    else
        echo -e "\033[0;32m✓ gcloud authenticated as: $active_account\033[0m"
    fi
}

# Run authentication check on first login
if [ -z "$GCLOUD_AUTH_CHECKED" ]; then
    export GCLOUD_AUTH_CHECKED=1
    _check_gcloud_auth
fi
EOF
    
    chown security:security /home/security/.bashrc
    
    # ============================================================================
    # SECURITY CHECKLIST
    # ============================================================================
    
    cat > /home/security/SECURITY_CHECKLIST.txt << 'EOF'
SECURITY SANDBOX - CHECKLIST
========================================

SECURITY PRINCIPLES:
1. Zero Host Contact - No shared folders, clipboard, or drag-drop
2. Network Isolation - Only DNS, HTTP, HTTPS outbound
3. Dual Users - security (no sudo) + admin (with sudo)
4. Ephemeral Tokens - Use throw-away PAT tokens only
5. Encrypted Shell - Use enc-env for sensitive operations

BEFORE HANDLING SENSITIVE DATA:
□ Verify environment: run 'check_sandbox'
□ Confirm you're logged in as 'security' user
□ Changed default passwords
□ Authenticate with gcloud if using GCP secrets

========================================
ENCRYPTED TRANSIENT ENVIRONMENT (enc-env)
========================================

Start encrypted shell:
  enc-env

Features:
• Password generated at runtime (NEVER stored)
• AES-256-XTS encryption on RAM-backed volume
• All data destroyed on exit
• Directories: $ENC_KEYS, $ENC_WALLETS, $ENC_SECRETS, $ENC_WORK

========================================
WALLET PROVISIONING
========================================

Install wallet extension:
  provision.sh metamask
  provision.sh rabby
  provision.sh phantom

With GCP secret:
  provision.sh metamask projects/PROJECT/secrets/NAME/versions/latest

Secret JSON format:
  {"seed_phrase": "word1 word2 ...", "password": "optional"}

Recommended workflow:
  1. enc-env                    # Start encrypted shell
  2. provision.sh metamask <secret>  # Retrieve credentials
  3. chromium-browser           # Import wallet
  4. exit                       # Destroy all traces

========================================
GOOGLE CLOUD CLI
========================================

Authenticate:
  gcloud auth login --no-launch-browser

Check status:
  gcloud auth list

Revoke (done automatically by secure_cleanup):
  gcloud auth revoke --all

WHEN USING GITHUB:
□ Create PAT with minimal scope (specific repo only)
□ Set short expiration (7-30 days)
□ Use: git clone https://USER:TOKEN@github.com/org/repo.git
□ Revoke PAT after use

DIRECTORY STRUCTURE:
~/keys/      - Store private keys here
~/work/      - Working directory
~/backups/   - Export data before destroying VM

BEFORE DESTROYING VM:
□ Copy important files to ~/backups/
□ Run 'secure_cleanup'
□ Verify backups are complete

INSTALLED TOOLS:
- git, gpg2, pass, keychain
- vim, nano, curl, wget
- openssh-client
- gcloud CLI
- Firefox ESR, Chromium (for wallet extensions)
- enc-env, provision.sh

NETWORK MONITORING:
Switch to admin user to view firewall logs:
  su - admin
  sudo tail -f /var/log/ufw.log
EOF
    
    chown security:security /home/security/SECURITY_CHECKLIST.txt
    
    # ============================================================================
    # COMPLETION
    # ============================================================================
    
    echo "=================================================="
    echo "✓ Security Sandbox Setup Complete"
    echo "=================================================="
    echo ""
    echo "Users created:"
    echo "  - security (login on boot) - Sudo: #{SECURITY_USER_HAS_SUDO}"
    if [ "#{ADMIN_USER_ENABLED}" = "true" ]; then
      echo "  - admin (system maintenance) - Sudo: YES"
    fi
    echo ""
    echo "⚠️  CHANGE DEFAULT PASSWORDS IMMEDIATELY!"
    echo ""
  SHELL
  
  # ============================================================================
  # POST-UP MESSAGE
  # ============================================================================
  
  config.vm.post_up_message = <<-MESSAGE
    ═══════════════════════════════════════════════════════════
    🔒 SECURITY SANDBOX READY
    ═══════════════════════════════════════════════════════════
    
    Configuration:
    - Security user sudo: #{SECURITY_USER_HAS_SUDO}
    - Admin user enabled: #{ADMIN_USER_ENABLED}
    - Resources: #{VM_MEMORY}MB RAM, #{VM_CPUS} CPUs
    - Encrypted volume: #{ENC_ENV_SIZE_MB}MB
    
    Login:
    - security / SecurePass123! (auto-login)
    #{"- admin / AdminPass123! (for maintenance)" if ADMIN_USER_ENABLED}
    
    ⚠️  CHANGE PASSWORDS IMMEDIATELY!
    
    NEW FEATURES:
    ─────────────────────────────────────────────────────────────
    🔐 Encrypted Shell:     enc-env
       Transient encrypted environment - password never stored
    
    ☁️  Google Cloud CLI:    gcloud auth login
       Authentication prompted on first login
    
    💳 Wallet Extensions:   provision.sh <wallet> [gcp_secret]
       Examples:
       - provision.sh metamask
       - provision.sh metamask projects/proj/secrets/wallet/versions/latest
    ─────────────────────────────────────────────────────────────
    
    Recommended Workflow:
    1. enc-env                          # Start encrypted shell
    2. provision.sh metamask <secret>   # Get wallet credentials
    3. chromium-browser                 # Set up wallet
    4. exit                             # Destroy all traces
    
    Commands:
    - vagrant halt    (stop VM)
    - vagrant destroy (delete VM)
    
    Read ~/SECURITY_CHECKLIST.txt in the VM
    ═══════════════════════════════════════════════════════════
  MESSAGE
end
