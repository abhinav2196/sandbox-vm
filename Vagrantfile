# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================================================
# Security Sandbox Vagrantfile
# ============================================================================
#
# Designed for handling sensitive security tasks with complete isolation
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
      keychain
    
    # Install lightweight desktop environment (XFCE)
    apt-get install -y xfce4 xfce4-goodies lightdm xfce4-screensaver
    
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
    echo "Date:     $(date)"
    echo "=========================================="
}

secure_cleanup() {
    echo "Performing secure cleanup..."
    history -c
    rm -f ~/.bash_history
    rm -rf ~/.cache/* 2>/dev/null
    echo "✓ Cleanup complete"
    echo "Remember to backup important files to ~/backups/ before destroying VM"
}

# Show status on login
if [ -f ~/SECURITY_CHECKLIST.txt ]; then
    echo ""
    echo "🔒 Security Sandbox Loaded"
    echo "Run 'check_sandbox' to verify environment"
    echo "Run 'secure_cleanup' before destroying VM"
    echo ""
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

BEFORE HANDLING SENSITIVE DATA:
□ Verify environment: run 'check_sandbox'
□ Confirm you're logged in as 'security' user
□ Changed default passwords

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
    ========================================
    🔒 SECURITY SANDBOX READY
    ========================================
    
    Configuration:
    - Security user sudo: #{SECURITY_USER_HAS_SUDO}
    - Admin user enabled: #{ADMIN_USER_ENABLED}
    - Resources: #{VM_MEMORY}MB RAM, #{VM_CPUS} CPUs
    
    Login:
    - security / SecurePass123! (auto-login)
    #{"- admin / AdminPass123! (for maintenance)" if ADMIN_USER_ENABLED}
    
    ⚠️  CHANGE PASSWORDS IMMEDIATELY!
    
    Commands:
    - vagrant halt    (stop VM)
    - vagrant destroy (delete VM)
    
    Read ~/SECURITY_CHECKLIST.txt in the VM
    ========================================
  MESSAGE
end
