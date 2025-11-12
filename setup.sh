#!/bin/bash
set -e

# Security Sandbox Setup Script
# Auto-detects platform and installs prerequisites

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo ""
    echo "=========================================="
    echo "  Security Sandbox Setup"
    echo "=========================================="
    echo ""
}

print_status() { echo -e "${BLUE}▸${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
app_exists() { [[ -d "/Applications/$1.app" ]] || [[ -d "$HOME/Applications/$1.app" ]]; }

# Detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            PLATFORM="macos_arm"
            PLATFORM_NAME="Apple Silicon Mac"
        else
            PLATFORM="macos_intel"
            PLATFORM_NAME="Intel Mac"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
        PLATFORM_NAME="Linux"
    else
        PLATFORM="unknown"
        PLATFORM_NAME="Unknown"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking system..."
    
    NEEDS_VAGRANT=false
    NEEDS_PROVIDER=false
    
    # Check Vagrant
    if command_exists vagrant; then
        VAGRANT_VERSION=$(vagrant --version | cut -d' ' -f2)
        print_success "Vagrant $VAGRANT_VERSION found"
    else
        print_warning "Vagrant not found"
        NEEDS_VAGRANT=true
    fi
    
    # Check providers based on platform
    case $PLATFORM in
        "macos_arm")
            # Check for QEMU or alternatives
            if command_exists qemu-system-aarch64; then
                print_success "QEMU found"
                PROVIDER="qemu"
            elif app_exists "UTM"; then
                print_warning "UTM found (needs command-line QEMU for Vagrant)"
                NEEDS_PROVIDER=true
                PROVIDER="qemu"
            elif command_exists prlctl || app_exists "Parallels Desktop"; then
                print_success "Parallels Desktop found"
                PROVIDER="parallels"
            elif command_exists vmrun || app_exists "VMware Fusion"; then
                print_success "VMware Fusion found"
                PROVIDER="vmware_desktop"
            else
                print_warning "No virtualization provider found"
                NEEDS_PROVIDER=true
                PROVIDER="qemu"
            fi
            ;;
            
        "macos_intel"|"linux")
            # Check for VirtualBox
            if command_exists vboxmanage; then
                VBOX_VERSION=$(vboxmanage --version 2>/dev/null || echo "unknown")
                print_success "VirtualBox $VBOX_VERSION found"
                PROVIDER="virtualbox"
            elif command_exists vmrun; then
                print_success "VMware found"
                PROVIDER="vmware_desktop"
            else
                print_warning "No virtualization provider found"
                NEEDS_PROVIDER=true
                PROVIDER="virtualbox"
            fi
            ;;
    esac
}

# Check Vagrant plugins
check_vagrant_plugin() {
    local plugin=$1
    if command_exists vagrant; then
        vagrant plugin list 2>/dev/null | grep -q "^$plugin " && return 0
    fi
    return 1
}

# Install on macOS
install_macos() {
    # Check Homebrew
    if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add to PATH
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        fi
        print_success "Homebrew installed"
    else
        print_success "Homebrew already installed"
    fi
    
    # Install Vagrant
    if [[ "$NEEDS_VAGRANT" == "true" ]]; then
        print_status "Installing Vagrant..."
        brew install vagrant
        print_success "Vagrant installed"
    fi
    
    # Install provider
    if [[ "$NEEDS_PROVIDER" == "true" ]]; then
        case $PROVIDER in
            "qemu")
                print_status "Installing QEMU..."
                brew install qemu
                print_success "QEMU installed"
                ;;
            "virtualbox")
                print_status "Installing VirtualBox..."
                brew install --cask virtualbox
                print_success "VirtualBox installed"
                ;;
        esac
    fi
    
    # Install Vagrant plugins (always check even if provider exists)
    if [[ "$PROVIDER" == "qemu" ]]; then
        if ! check_vagrant_plugin "vagrant-qemu"; then
            print_status "Installing vagrant-qemu plugin..."
            vagrant plugin install vagrant-qemu
            print_success "Plugin installed"
        else
            print_success "vagrant-qemu plugin already installed"
        fi
    elif [[ "$PROVIDER" == "parallels" ]]; then
        if ! check_vagrant_plugin "vagrant-parallels"; then
            print_status "Installing vagrant-parallels plugin..."
            vagrant plugin install vagrant-parallels
            print_success "Plugin installed"
        else
            print_success "vagrant-parallels plugin already installed"
        fi
    elif [[ "$PROVIDER" == "vmware_desktop" ]]; then
        if ! check_vagrant_plugin "vagrant-vmware-desktop"; then
            print_warning "vagrant-vmware-desktop plugin requires license (\$80)"
            read -p "Install now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                vagrant plugin install vagrant-vmware-desktop
                print_success "Plugin installed (don't forget to license it)"
            fi
        else
            print_success "vagrant-vmware-desktop plugin already installed"
        fi
    fi
}

# Install on Linux
install_linux() {
    print_status "Installing packages..."
    
    # Detect package manager
    if command_exists apt-get; then
        sudo apt-get update
        
        if [[ "$NEEDS_VAGRANT" == "true" ]]; then
            sudo apt-get install -y vagrant
        fi
        
        if [[ "$NEEDS_PROVIDER" == "true" && "$PROVIDER" == "virtualbox" ]]; then
            sudo apt-get install -y virtualbox
        fi
        
        print_success "Packages installed"
    elif command_exists dnf; then
        if [[ "$NEEDS_VAGRANT" == "true" ]]; then
            sudo dnf install -y vagrant
        fi
        if [[ "$NEEDS_PROVIDER" == "true" && "$PROVIDER" == "virtualbox" ]]; then
            sudo dnf install -y VirtualBox
        fi
        print_success "Packages installed"
    else
        print_error "Unsupported package manager"
        print_status "Please install manually:"
        echo "  - Vagrant: https://www.vagrantup.com/downloads"
        echo "  - VirtualBox: https://www.virtualbox.org/wiki/Linux_Downloads"
        exit 1
    fi
}

# Set default provider
configure_provider() {
    local shell_rc=""
    
    if [[ -n "$ZSH_VERSION" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "VAGRANT_DEFAULT_PROVIDER=$PROVIDER" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Vagrant default provider (Security Sandbox)" >> "$shell_rc"
            echo "export VAGRANT_DEFAULT_PROVIDER=$PROVIDER" >> "$shell_rc"
            export VAGRANT_DEFAULT_PROVIDER=$PROVIDER
            print_success "Default provider set to: $PROVIDER"
        fi
    fi
}

# Test installation
test_installation() {
    print_status "Testing installation..."
    
    if ! command_exists vagrant; then
        print_error "Vagrant not found in PATH"
        return 1
    fi
    
    vagrant version >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        print_success "Installation successful!"
        return 0
    else
        print_error "Installation verification failed"
        return 1
    fi
}

# Main
main() {
    print_header
    
    detect_platform
    print_status "Detected: $PLATFORM_NAME"
    echo ""
    
    check_prerequisites
    echo ""
    
    # Check if plugins need to be installed
    NEEDS_PLUGIN=false
    if command_exists vagrant; then
        case $PROVIDER in
            "qemu")
                if ! check_vagrant_plugin "vagrant-qemu"; then
                    NEEDS_PLUGIN=true
                fi
                ;;
            "parallels")
                if ! check_vagrant_plugin "vagrant-parallels"; then
                    NEEDS_PLUGIN=true
                fi
                ;;
            "vmware_desktop")
                if ! check_vagrant_plugin "vagrant-vmware-desktop"; then
                    NEEDS_PLUGIN=true
                fi
                ;;
        esac
    fi
    
    # Nothing to install?
    if [[ "$NEEDS_VAGRANT" == "false" && "$NEEDS_PROVIDER" == "false" && "$NEEDS_PLUGIN" == "false" ]]; then
        print_success "All prerequisites already installed!"
        configure_provider
        echo ""
        print_success "Ready to start: vagrant up"
        exit 0
    fi
    
    # Confirm installation
    echo "The following will be installed:"
    [[ "$NEEDS_VAGRANT" == "true" ]] && echo "  • Vagrant"
    [[ "$NEEDS_PROVIDER" == "true" ]] && echo "  • $PROVIDER"
    [[ "$NEEDS_PLUGIN" == "true" ]] && echo "  • Vagrant plugin for $PROVIDER"
    echo ""
    
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Setup cancelled"
        exit 0
    fi
    
    # Install
    echo ""
    case $PLATFORM in
        "macos_arm"|"macos_intel")
            install_macos
            ;;
        "linux")
            install_linux
            ;;
        *)
            print_error "Unsupported platform"
            exit 1
            ;;
    esac
    
    configure_provider
    echo ""
    
    # Test
    if test_installation; then
        echo ""
        print_header
        print_success "Setup complete!"
        echo ""
        echo "Next steps:"
        echo "  1. Restart your terminal (or run: source ~/.zshrc)"
        echo "  2. Run: vagrant up"
        echo "  3. Login: security / SecurePass123!"
        echo ""
    else
        print_error "Setup completed with errors"
        exit 1
    fi
}

main "$@"

