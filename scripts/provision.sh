#!/bin/bash
# Main VM provisioning - installs base system and tools
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing base packages"
apt-get update -qq
apt-get install -y -qq \
    git gnupg2 curl wget vim jq \
    cryptsetup pass openssh-client \
    xfce4 xfce4-goodies lightdm \
    firefox-esr chromium-browser 2>/dev/null || apt-get install -y -qq chromium

echo "==> Installing gcloud CLI"
if ! command -v gcloud &>/dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    apt-get update -qq && apt-get install -y -qq google-cloud-cli
fi

echo "==> Creating user"
if ! id security &>/dev/null; then
    useradd -m -s /bin/bash security
    echo "security:changeme" | chpasswd
    mkdir -p /home/security/{Desktop,work}
    chown -R security:security /home/security
fi

echo "==> Configuring auto-login"
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/autologin.conf <<EOF
[Seat:*]
autologin-user=security
EOF

echo "==> Disabling unnecessary services"
for svc in snapd bluetooth cups avahi-daemon; do
    systemctl disable $svc 2>/dev/null || true
done

echo "==> Done"

