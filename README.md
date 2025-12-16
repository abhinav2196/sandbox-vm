# Secure Signing VM

Isolated VM for blockchain signing with GCP secrets injection.

## Quick Start

```bash
# 1. Install (one-time)
./setup.sh

# 2. Configure
cp config.example config.yaml
# Edit: add your GCP project + secret labels

# 3. Run
vagrant up

# 4. Inside VM - fetch secrets
sudo /vagrant_config/scripts/secrets.sh
# Enter encryption password (never stored)
# Authenticate with GCP
# Secrets available at /mnt/secrets/
```

## Config

```yaml
network_enabled: true  # false = fully offline

secrets:
  - label: wallet-seed
    project: my-gcp-project
```

## Commands

| Command | Action |
|---------|--------|
| `vagrant up` | Start VM |
| `vagrant halt` | Stop VM |
| `vagrant destroy` | Delete VM + secrets |
| `vagrant ssh` | SSH access |

## Security

- No host clipboard/folders access
- Network: DNS/HTTP/HTTPS only (or disabled)
- Secrets in encrypted RAM volume
- Password prompted at runtime, never stored

See [ARCHITECTURE.md](ARCHITECTURE.md) for design details.
