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

# Connect GUI (SSH tunnel + VNC)
vagrant ssh -- -L 5901:localhost:5901   # keep open
open vnc://localhost:5901                # pw: changeme

# Better clipboard support: use TigerVNC instead of macOS Screen Sharing
brew install --cask tigervnc-viewer
open "/Applications/TigerVNC Viewer 1.15.0.app"
# → Connect to: localhost:5901 (pw: changeme)
# → Copy/paste works: Cmd+C on Mac ↔ Ctrl+Shift+V in VM

# Inside VM: fetch secrets
su - security
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
# → enter encryption password
# → complete gcloud auth
# → secrets available at /mnt/secrets/

# Run Firefox with ephemeral profile (destroyed on exit)
mkdir -p /mnt/secrets/firefox-profile
DISPLAY=:1 firefox --profile /mnt/secrets/firefox-profile --no-remote &
# → Install MetaMask, import keys, sign transactions
# → All browser data lives in encrypted RAM

# Exit destroys secrets + browser data
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

## Troubleshooting

### Auth failed / Malformed auth code

If gcloud authentication fails (e.g., "Malformed auth code"), reset and retry:

```bash
# Cleanup the failed session
sudo /usr/local/sbin/secrets.sh cleanup

# Start fresh
sudo /usr/local/sbin/secrets.sh /vagrant_config/config.yaml
```

**Tips for pasting the auth code:**
- Triple-click to select the entire code in your browser
- Use **Ctrl+Shift+V** to paste in the VM terminal
- Paste within 30 seconds (codes expire quickly)

### Firefox: "cannot open display" or "authorization required"

If Firefox fails to open from the secrets session, allow X connections from local users.

Run in a **separate terminal** (not in the secrets session):

```bash
vagrant ssh -c "DISPLAY=:1 xhost +local:"
```

Then retry Firefox in your secrets session.

### Clipboard not working

The macOS built-in VNC client has limited clipboard support. Use TigerVNC instead:

```bash
brew install --cask tigervnc-viewer
open "/Applications/TigerVNC Viewer 1.15.0.app"
```

Connect to `localhost:5901` (password: `changeme`). Clipboard sync works automatically.

## Security

- Secrets live in LUKS-encrypted RAM volume
- gcloud blocked for normal user
- No credentials persist after exit
