#!/bin/bash
# Main VM provisioning - installs base system and tools
# Usage: provision.sh [gui|nogui]
set -e

GUI_MODE="${1:-nogui}"
export DEBIAN_FRONTEND=noninteractive

sync_time() {
    echo "==> Syncing system time (avoids apt 'not valid yet' errors)"
    # We do not rely on NTP (UDP/123) since firewall may block it.
    # Instead, use HTTPS Date header as a time source.
    local date_hdr
    date_hdr="$(curl -fsSI https://google.com 2>/dev/null | awk -F': ' 'tolower($1)=="date"{print $2}' | tr -d '\r' | head -1 || true)"
    if [[ -n "$date_hdr" ]]; then
        date -u -s "$date_hdr" >/dev/null 2>&1 || true
    fi
    echo "==> VM time (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
}

sync_time

echo "==> Updating apt..."
apt-get update || apt-get -o Acquire::Check-Valid-Until=false update

echo "==> Installing base packages..."
apt-get install -y \
    git gnupg2 curl wget vim jq \
    cryptsetup pass openssh-client

if [[ "$GUI_MODE" == "gui" ]]; then
    echo "==> Disabling snap (slow)..."
    systemctl disable --now snapd.socket snapd.service 2>/dev/null || true
    
    echo "==> Adding Mozilla apt repo (fast Firefox, no snap)..."
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | \
        gpg --dearmor -o /etc/apt/keyrings/packages.mozilla.org.gpg 2>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main" \
        > /etc/apt/sources.list.d/mozilla.list
    # Prefer Mozilla repo over Ubuntu's snap-based firefox
    cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1001
EOF
    apt-get update
    
    echo "==> Installing GUI packages (~5-7 min)..."
    apt-get install -y xfce4 lightdm firefox tigervnc-standalone-server
    
    # Pre-configure VNC for both vagrant and security users
    for user in vagrant security; do
        home_dir=$(eval echo ~$user)
        mkdir -p "$home_dir/.vnc"
        cat > "$home_dir/.vnc/xstartup" << 'XEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XEOF
        chmod +x "$home_dir/.vnc/xstartup"
        echo "changeme" | vncpasswd -f > "$home_dir/.vnc/passwd"
        chmod 600 "$home_dir/.vnc/passwd"
        chown -R $user:$user "$home_dir/.vnc"
    done
    
    # Suppress polkit color-managed-device prompts
    cat > /etc/polkit-1/localauthority/50-local.d/color.pkla << 'PEOF'
[Allow colord for all users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=yes
ResultInactive=yes
ResultActive=yes
PEOF

    # Create systemd service to auto-start VNC for vagrant user
    cat > /etc/systemd/system/vncserver@.service << 'VEOF'
[Unit]
Description=TigerVNC server for %i
After=network.target

[Service]
Type=forking
User=vagrant
Group=vagrant
WorkingDirectory=/home/vagrant
ExecStart=/usr/bin/vncserver :%i -geometry 1280x800 -localhost no
ExecStop=/usr/bin/vncserver -kill :%i
Restart=on-failure

[Install]
WantedBy=multi-user.target
VEOF
    systemctl daemon-reload
    systemctl enable vncserver@1
    systemctl start vncserver@1 || true
else
    echo "==> Skipping GUI (set gui_enabled: true in config.yaml to install)"
fi

echo "==> Installing gcloud CLI"
if ! command -v gcloud &>/dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    apt-get update -qq && apt-get install -y -qq google-cloud-cli
fi

echo "==> Locking down gcloud (root-only; credentials stored only in encrypted mount)"
if command -v gcloud &>/dev/null; then
    groupadd -f gcloud >/dev/null 2>&1 || true
    for bin in /usr/bin/gcloud /usr/bin/gsutil /usr/bin/bq; do
        if [[ -f "$bin" ]]; then
            chown root:gcloud "$bin" || true
            chmod 750 "$bin" || true
        fi
    done
fi

echo "==> Creating user"
if ! id security &>/dev/null; then
    useradd -m -s /bin/bash security
    echo "security:changeme" | chpasswd
    mkdir -p /home/security/{Desktop,work}
    chown -R security:security /home/security
fi

echo "==> Installing helper scripts into /usr/local (root-owned)"
install -d -m 755 /usr/local/sbin /usr/local/bin
if [[ -d /vagrant_config/scripts ]]; then
    install -m 755 /vagrant_config/scripts/secrets.sh /usr/local/sbin/secrets.sh
    install -m 755 /vagrant_config/scripts/secure-browser.sh /usr/local/bin/secure-browser
    install -m 755 /vagrant_config/scripts/harden.sh /usr/local/sbin/harden.sh 2>/dev/null || true
    install -m 755 /vagrant_config/scripts/network.sh /usr/local/sbin/network.sh 2>/dev/null || true
fi

if [[ "$GUI_MODE" == "gui" ]]; then
    echo "==> Configuring auto-login"
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/autologin.conf <<EOF
[Seat:*]
autologin-user=security
EOF
fi

echo "==> Disabling unnecessary services"
for svc in snapd bluetooth cups avahi-daemon; do
    systemctl disable $svc 2>/dev/null || true
done

echo "==> Restricting sudo: allow only secrets session for security user"
if command -v sudo >/dev/null 2>&1 && id security >/dev/null 2>&1; then
    # Allow security to run ONLY the secrets wrapper (no shell, no arbitrary sudo)
    cat > /etc/sudoers.d/security-secrets <<'EOF'
security ALL=(root) NOPASSWD: /usr/local/sbin/secrets.sh
EOF
    chmod 440 /etc/sudoers.d/security-secrets
fi

echo "==> Done"
# Note: harden.sh runs as separate final provisioner in Vagrantfile

