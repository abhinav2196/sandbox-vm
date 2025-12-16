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
    ufw allow out 53/udp   # DNS
    ufw allow out 80/tcp   # HTTP
    ufw allow out 443/tcp  # HTTPS
    ufw --force enable
    echo "==> Firewall: DNS/HTTP/HTTPS only"
}

disable_network() {
    apt-get install -y -qq ufw
    ufw --force reset
    ufw default deny incoming
    ufw default deny outgoing
    ufw --force enable
    echo "==> Network disabled"
}

case "$ACTION" in
    enable)  setup_firewall ;;
    disable) disable_network ;;
    *)       echo "Usage: network.sh <enable|disable>" ;;
esac

