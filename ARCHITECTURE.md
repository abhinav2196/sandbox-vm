# Secure Signing VM

## Purpose

Isolated VM for blockchain signing operations with secrets from GCP.

## Requirements

| # | Requirement | Implementation |
|---|-------------|----------------|
| 1 | Secure VM for signing/transfers | Ubuntu VM with XFCE, isolated from host |
| 2 | GCP secrets injection | `config.yaml` lists secret labels → fetched at provision time |
| 3 | Encrypted storage | LUKS volume, password prompted at runtime (never stored) |
| 4 | Network toggle | `config.yaml`: `network_enabled: true/false` |
| 5 | GUI desktop | XFCE with browser for wallet extensions |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Host Machine                        │
│                                                         │
│  config.yaml ──────┐                                    │
│  (secret labels)   │                                    │
│                    ▼                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Vagrant VM (Ubuntu)                 │   │
│  │                                                  │   │
│  │  ┌──────────────┐    ┌───────────────────────┐  │   │
│  │  │  GCP Auth    │───▶│  Secrets Fetched      │  │   │
│  │  │  (runtime)   │    │  (encrypted storage)  │  │   │
│  │  └──────────────┘    └───────────────────────┘  │   │
│  │                                                  │   │
│  │  ┌──────────────┐    ┌───────────────────────┐  │   │
│  │  │  XFCE GUI    │    │  Browser + Wallet     │  │   │
│  │  │              │    │  Extensions           │  │   │
│  │  └──────────────┘    └───────────────────────┘  │   │
│  │                                                  │   │
│  │  Network: DNS/HTTP/HTTPS only (or disabled)     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Config File

```yaml
# config.yaml
network_enabled: true

secrets:
  - label: wallet-seed
    project: my-gcp-project
  - label: signing-key
    project: my-gcp-project
```

## Security Model

1. **No host access** - shared folders/clipboard disabled
2. **Network isolation** - outbound DNS/HTTP/HTTPS only (or fully offline)
3. **Encrypted RAM volume** - password entered at runtime, never stored
4. **gcloud tokens never persist** - `CLOUDSDK_CONFIG` is set inside `/mnt/secrets` so OAuth tokens are destroyed with the mount
5. **gcloud is root-only** - normal VM users cannot run `gcloud` directly
6. **Private mount namespace** - decrypted `/mnt/secrets` is only visible inside the secrets session
7. **Auto-destroy** - secrets wiped when the secrets session exits

## Files

```
├── config.yaml      # Your secrets config (git-ignored)
├── config.example   # Template
├── Vagrantfile      # VM definition
├── build-box.sh     # Package VM into reusable box
├── deploy.sh        # Fast deploy from pre-built box
├── scripts/
│   ├── provision.sh # Base system setup
│   ├── network.sh   # Firewall config
│   └── secrets.sh   # GCP fetch + encrypt
└── README.md        # Quick start
```

## Workflow

```bash
# FIRST TIME (slow, ~10 min)
vagrant up           # Provision VM
./build-box.sh       # Package into signing-vm.box

# SUBSEQUENT (fast, ~20 sec)
./deploy.sh          # Start from pre-built box

# INSIDE VM
sudo /vagrant_config/scripts/secrets.sh
# → Enter encryption password
# → Authenticate with GCP
# → Secrets at /mnt/secrets/

# CLEANUP
vagrant destroy      # Wipes all secrets
```

