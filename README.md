# Secure Signing VM

Isolated VM for blockchain signing with GCP secrets injection.

## Quick Start

```bash
# 1. Setup
./setup.sh
cp config.example config.yaml  # edit with your GCP project

# 2. First run (slow - builds image)
vagrant up

# 3. Package for fast deploys
./build-box.sh

# 4. Fast deploys (seconds)
./deploy.sh
```

## Fast Deploy Workflow

```
Build once:     vagrant up → ./build-box.sh → signing-vm.box (5-10 min)
Deploy fast:    ./deploy.sh → VM ready (10-20 sec)
```

## Inside VM

```bash
vagrant ssh
sudo /vagrant_config/scripts/secrets.sh  # fetch GCP secrets
```

## Config

```yaml
network_enabled: true  # false = offline mode

secrets:
  - label: wallet-seed
    project: my-gcp-project
```

## Commands

| Command | Action |
|---------|--------|
| `./deploy.sh` | Fast start from pre-built box |
| `./cleanup.sh vm` | Destroy VM (keep box) |
| `./cleanup.sh box` | Remove pre-built box |
| `./cleanup.sh all` | Destroy VM + remove box |
| `vagrant halt` | Stop VM (keep state) |

See [ARCHITECTURE.md](ARCHITECTURE.md) for design.
