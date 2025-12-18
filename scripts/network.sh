#!/bin/bash
# Configure network isolation
# Usage: network.sh <enable|disable>
set -e

ACTION="${1:-enable}"

setup_firewall() {
    apt-get install -y -qq ufw
    ufw --force reset
    ufw default deny incoming
    ufw default deny outgoing
    ufw allow in 22/tcp    # SSH (for Vagrant)
    ufw allow out 22/tcp   # SSH
    ufw allow out 53/udp   # DNS
    ufw allow out 80/tcp   # HTTP
    ufw allow out 443/tcp  # HTTPS
    ufw --force enable
    echo "==> Firewall: SSH/DNS/HTTP/HTTPS"
}

disable_network() {
    apt-get install -y -qq ufw
    ufw --force reset
    ufw default deny incoming
    ufw default deny outgoing
    # Still allow SSH so Vagrant access works even in offline mode
    ufw allow in 22/tcp
    ufw allow out 22/tcp
    ufw --force enable
    echo "==> Network disabled"
}

case "$ACTION" in
    enable)  setup_firewall ;;
    disable) disable_network ;;
    *)       echo "Usage: network.sh <enable|disable>" ;;
esac

