SHELL := /bin/bash
.PHONY: setup build deploy vm cleanup vm-clean box-clean help all

# read ssh_port from config (macOS awk compatible)
CONFIG_SSH_PORT := $(shell awk -F: '/^[[:space:]]*ssh_port/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' config.yaml 2>/dev/null)
VAGRANT_SSH_PORT ?= $(if $(CONFIG_SSH_PORT),$(CONFIG_SSH_PORT),50223)

help:
	@printf "Targets:\n"
	@printf "  setup        Install host requirements (Vagrant, provider)\n"
	@printf "  build        Package a provisioned VM into signing-vm.box\n"
	@printf "  deploy       Start a VM from signing-vm.box (fast path)\n"
	@printf "  vm           Run plain `vagrant up` (slow, first-time provisioning)\n"
	@printf "  cleanup      Destroy VM + remove box (wraps cleanup.sh all)\n"
	@printf "  vm-clean     Destroy running VM (keep box)\n"
	@printf "  box-clean    Remove pre-built box file\n"

all: help

setup:
	./setup.sh

build:
	./build-box.sh

deploy:
	./deploy.sh

vm:
	@VAGRANT_SSH_PORT=$(VAGRANT_SSH_PORT) vagrant up

cleanup:
	./cleanup.sh all

vm-clean:
	./cleanup.sh vm

box-clean:
	./cleanup.sh box
