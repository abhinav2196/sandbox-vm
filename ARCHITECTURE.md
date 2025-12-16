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
3. **Encrypted RAM volume** - password generated at runtime, never stored
4. **Auto-destroy** - secrets wiped on VM shutdown

## Files

```
├── config.yaml      # Your secrets config (git-ignored)
├── config.example   # Template
├── Vagrantfile      # VM definition
├── scripts/
│   ├── provision.sh # Main setup
│   └── secrets.sh   # GCP fetch + encrypt
└── README.md        # Quick start
```

## Workflow

```bash
# 1. Configure
cp config.example config.yaml
# Edit: add your GCP project and secret labels

# 2. Start VM
vagrant up
# Prompts: encryption password + GCP auth

# 3. Use
# Secrets available in /mnt/secrets (encrypted)
# Browser wallets ready for import

# 4. Destroy
vagrant destroy  # All secrets wiped
```

