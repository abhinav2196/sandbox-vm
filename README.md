# Secure Signing VM

Isolated VM for blockchain signing. Secrets fetched from GCP into encrypted RAM — destroyed on exit.

## Setup (once)

```bash
./setup.sh
```

Alternative:

```bash
make setup
```

Edit `config.yaml`:
```yaml
gui_enabled: true
secrets:
  - label: your-secret-name
    project: your-gcp-project
```

## Usage

```bash
# Start VM (~7 min first time, ~30 sec after build-box)
# Set `VAGRANT_SSH_PORT` to avoid host collisions if needed
VAGRANT_SSH_PORT=${VAGRANT_SSH_PORT:-50223} vagrant up

# Connect GUI
vagrant ssh -- -L 5901:localhost:5901   # keep open
open vnc://localhost:5901                # pw: changeme

# Inside VM: fetch secrets
su - security
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
# → enter encryption password
# → complete gcloud auth
# → secrets available at /mnt/secrets/

# Exit destroys secrets
exit
```

## Fast Deploys

```bash
./build-box.sh    # save provisioned state (once)
./deploy.sh       # start in ~30 sec (every time)
```

## Config Options

| Option | Values | Description |
|--------|--------|-------------|
| `gui_enabled` | true/false | Desktop + Firefox via VNC |
| `network_enabled` | true/false | Internet access |

## Security

- Secrets live in LUKS-encrypted RAM volume
- gcloud blocked for normal user
- No credentials persist after exit
