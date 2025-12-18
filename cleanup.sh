#!/bin/bash
# Cleanup script for VMs and boxes
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

usage() {
    echo "Usage: ./cleanup.sh <vm|box|all>"
    echo ""
    echo "  vm   - Destroy running VM (keeps box for fast redeploy)"
    echo "  box  - Remove pre-built box (keeps base vagrant boxes)"
    echo "  all  - Destroy VM + remove pre-built box"
    echo ""
}

cleanup_vm() {
    echo -e "${GREEN}==> Destroying VM...${NC}"
    vagrant destroy -f 2>/dev/null || true
    rm -rf .vagrant
    echo -e "${GREEN}==> VM destroyed${NC}"
}

cleanup_box() {
    echo -e "${GREEN}==> Removing pre-built box...${NC}"
    vagrant box remove signing-vm-base -f 2>/dev/null || true
    rm -f signing-vm.box
    echo -e "${GREEN}==> Box removed${NC}"
}

case "${1:-}" in
    vm)
        cleanup_vm
        ;;
    box)
        cleanup_box
        ;;
    all)
        cleanup_vm
        cleanup_box
        ;;
    *)
        usage
        echo "Current state:"
        echo -n "  VM:  "; vagrant status 2>/dev/null | grep -E "running|stopped|not created" || echo "not created"
        echo -n "  Box: "; vagrant box list 2>/dev/null | grep signing-vm-base || echo "not built"
        ;;
esac

