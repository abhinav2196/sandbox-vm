# Security Sandbox Environment

A completely isolated VM for handling sensitive security operations (private keys, certificates, encryption) with minimal attack surface.

---

## Security Principles

1. **Zero Host Contact** - No shared folders, clipboard, or drag-and-drop with host OS
2. **Network Isolation** - Only essential outbound connections (DNS, HTTP, HTTPS). Everything else blocked
3. **Dual User Model** - Non-privileged user for security work, admin user for system maintenance (configurable)
4. **Ephemeral Tokens** - Use throw-away PAT tokens scoped to specific repositories only

## Configuration

Edit `Vagrantfile` to customize:

```ruby
SECURITY_USER_HAS_SUDO = false  # Set to true for sudo access
ADMIN_USER_ENABLED = true       # Set to false to disable admin user
VM_MEMORY = "2048"              # Adjust RAM (MB)
VM_CPUS = 2                     # Adjust CPU cores
```

---

## Quick Start

### Prerequisites

**Apple Silicon Mac:**
```bash
brew install qemu vagrant
vagrant plugin install vagrant-qemu
export VAGRANT_DEFAULT_PROVIDER=qemu
```

**Intel Mac:**
```bash
brew install --cask virtualbox vagrant
```

**Linux:**
```bash
sudo apt install virtualbox vagrant
```

### Start the Sandbox

```bash
# After setup.sh, restart your terminal OR run:
eval "$(/opt/homebrew/bin/brew shellenv)"  # macOS
# OR
source ~/.bashrc  # Linux

# Then start the sandbox:
vagrant up
```

**First run:** Takes 5-10 minutes (downloads Ubuntu, installs tools)  
**Subsequent starts:** ~30 seconds

### Access the Environment

**Intel Mac/Linux (VirtualBox):** GUI window opens automatically  

**Apple Silicon (QEMU):** Headless by default. Two options:
1. **SSH Access** (Recommended for security work):
   ```bash
   vagrant ssh
   # All tools available via CLI
   ```

2. **GUI via UTM** (if you need desktop):
   - Use UTM app (you already have it)
   - Import the Vagrant box manually
   - See README section below for UTM setup

**Login:** `security` / `SecurePass123!`  
**⚠️ Change password immediately!**

---

## User Accounts

### `security` User (Default)
- **Purpose**: All security operations
- **Login**: `security` / `SecurePass123!`
- **Access**: No sudo by default (configurable via `SECURITY_USER_HAS_SUDO`)
- **Use for**: Handling keys, encryption, sensitive operations

### `admin` User (System Maintenance)
- **Purpose**: Installing packages, system updates
- **Login**: `admin` / `AdminPass123!`
- **Access**: Full sudo access
- **Use for**: Installing tools, updating system
- **Note**: Can be disabled via `ADMIN_USER_ENABLED = false`

**⚠️ Change both passwords on first login!**

---

## Daily Usage

```bash
# Start VM
vagrant up

# Stop VM (keeps data)
vagrant halt

# Delete VM completely (recommended after sensitive operations)
vagrant destroy

# SSH access (optional)
vagrant ssh
```

---

## Inside the VM

### Key Directories (`security` user)
```
~/keys/              # Store private keys here
~/work/              # Working directory for operations
~/backups/           # Export data before destroying VM
```

### Pre-installed Tools
- **git** - Version control
- **gpg2** - Encryption/decryption
- **pass** - Password manager
- **openssh** - SSH operations
- **vim, nano** - Text editors
- **curl, wget** - Download tools

### Using GitHub with PAT Tokens

Create a PAT with minimal scope (Settings → Developer Settings → PAT):
- Scope: Only specific repos needed
- Expiration: Short (7-30 days)
- Use once, then revoke

```bash
# Clone with PAT
git clone https://USERNAME:TOKEN@github.com/org/repo.git

# Or configure credential helper
git config --global credential.helper store
# Enter PAT when prompted (stored in ~/.git-credentials)
```

### Security Checklist

Before using the VM:
```bash
# Verify you're in the sandbox
whoami              # Should show: security
hostname            # Should show: vagrant-security-sandbox
check_sandbox       # Shows sandbox status
```

Before destroying the VM:
```bash
# Copy important data to ~/backups/
# Then run secure cleanup
secure_cleanup      # Clears history and temp files
```

---

## Network Isolation

**Allowed Outbound:**
- Port 53 (DNS)
- Port 80 (HTTP)
- Port 443 (HTTPS)

**Blocked:**
- All inbound connections
- All other outbound ports
- Host system access

**To monitor connections:**
```bash
# As admin user
sudo tail -f /var/log/ufw.log
```

---

## Platform-Specific Notes

### Apple Silicon (M1/M2/M3)
- Uses QEMU (free, open source)
- Don't use VirtualBox (poor ARM support)
- Alternative: VMware Fusion or Parallels (paid)

### Intel Mac
- Uses VirtualBox (free)
- Tested on macOS 10.15+

### Linux
- Uses VirtualBox (free)
- Tested on Ubuntu 20.04+

---

## Troubleshooting

### VM won't start
```bash
vagrant destroy -f
vagrant up
```

### Need to install a tool
```bash
# Switch to admin user in VM
su - admin
# Password: AdminPass123!

# Install package
sudo apt update
sudo apt install <package>

# Switch back to security user
su - security
```

### Forgot to backup data before destroy
Data is gone. Always backup to `~/backups/` before destroying.

### Performance issues
- Close unnecessary host applications
- Ensure 10GB+ free disk space
- VM uses 2GB RAM, 2 CPU cores

### Provider issues
```bash
# Force specific provider
vagrant up --provider=qemu           # Apple Silicon
vagrant up --provider=virtualbox     # Intel Mac/Linux
vagrant up --provider=vmware_desktop # VMware
```

---

## Resource Usage

- **RAM**: 2GB (out of your 16GB)
- **Disk**: ~8GB
- **CPU**: 2 cores
- **Network**: Isolated, minimal bandwidth

---

## Security Best Practices

1. ✅ Always verify you're in the sandbox before handling sensitive data
2. ✅ Use `security` user (not `admin`) for all security operations
3. ✅ Use throw-away PAT tokens with minimal scope
4. ✅ Destroy VM after completing sensitive operations
5. ✅ Never store sensitive data only in VM (backup first)
6. ✅ Change default passwords immediately
7. ✅ Keep VM updated (as `admin` user): `sudo apt update && sudo apt upgrade`

---

## Files

```
sandbox-scripts/
├── README.md       # This file
├── Vagrantfile     # VM configuration
└── .gitignore      # Prevents committing sensitive files
```

---

## Support

- **Configuration**: Edit `Vagrantfile`
- **Issues**: Check troubleshooting section above
- **Security concerns**: Review security principles at top

---

**Ready?** Run `vagrant up` to start! 🚀
