# Secure Signing VM

Isolated VM for blockchain signing. Secrets fetched from GCP into encrypted RAM — destroyed on exit.

## Quick Start

```bash
# 1. Install prerequisites (once)
./setup.sh

# 2. Configure
cp config.example config.yaml
# Edit config.yaml with your GCP project + secret labels

# 3. Start VM (~7 min first time)
vagrant up

# 4. Connect via VNC
vagrant ssh -- -L 5901:localhost:5901   # keep open
open vnc://localhost:5901                # pw: changeme

# 5. Inside VM: fetch secrets
su - security
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
# → enter encryption password
# → complete gcloud auth
# → secrets available at /mnt/secrets/

# 6. Use browser with ephemeral profile
secure-browser &
# → Install MetaMask, import keys, sign transactions

# 7. Exit destroys everything
exit
```

## Fast Deploys

```bash
./build-box.sh    # package provisioned VM (once)
./deploy.sh       # start in ~30 sec (every time)
```

## Config

```yaml
# config.yaml
network_enabled: true
gui_enabled: true
vm_memory: 6144
vm_cpus: 6

secrets:
  - label: wallet-seed
    project: my-gcp-project
```

| Option | Description |
|--------|-------------|
| `gui_enabled` | Desktop + Firefox via VNC |
| `network_enabled` | Internet access (DNS/HTTP/HTTPS only) |
| `vm_memory` | RAM in MB |
| `vm_cpus` | CPU cores |

## Security Model

1. **Encrypted RAM volume** — secrets stored in LUKS-encrypted tmpfs at `/mnt/secrets`
2. **Mount namespace isolation** — other VM sessions cannot see decrypted secrets
3. **gcloud locked to root** — normal users cannot run `gcloud` directly
4. **Auto-cleanup** — volume destroyed when secrets session exits
5. **No credential persistence** — OAuth tokens live only in encrypted mount

## Architecture

```
Host
 └── Vagrant VM (Ubuntu + XFCE)
      └── /mnt/secrets/ (encrypted RAM)
           ├── *.json (GCP secrets)
           ├── gcloud/ (OAuth tokens)
           └── firefox-profile/ (wallet data)
```

## Files

```
├── config.yaml         # Your config (git-ignored)
├── Vagrantfile         # VM definition
├── scripts/
│   ├── provision.sh    # System setup
│   ├── harden.sh       # Security lockdown (auto-runs)
│   ├── secrets.sh      # Encrypted volume + GCP fetch
│   ├── secure-browser.sh
│   └── eth-sign.py     # Ethereum signing
├── build-box.sh        # Package VM
├── deploy.sh           # Fast start
└── cleanup.sh          # Destroy VM/box
```

## Troubleshooting

**Auth failed / Malformed auth code**
```bash
sudo /usr/local/sbin/secrets.sh cleanup
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
```

**Firefox won't open**
```bash
# In separate terminal:
vagrant ssh -c "DISPLAY=:1 xhost +local:"
```

**Clipboard not working** — Use TigerVNC instead of macOS Screen Sharing:
```bash
brew install --cask tigervnc-viewer
```
