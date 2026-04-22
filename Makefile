.PHONY: install install-dry install-force wire uninstall help

SHELL := /usr/bin/env bash
ROOT := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

help:
	@echo "tmux-attic make targets:"
	@echo "  install          Wire session_manager.tmux into ~/.tmux.conf"
	@echo "  install-dry      Preview the wiring — no files touched"
	@echo "  install-force    Wire even if stray attic lines found outside sentinels"
	@echo "  wire             Alias for install (explicit about what it does)"
	@echo "  uninstall        Strip tmux-attic managed blocks from ~/.tmux.conf"
	@echo ""
	@echo "Most users should install via TPM instead:"
	@echo "  set -g @plugin 'SynapticSage/tmux-attic'"

install:
	@$(ROOT)install.sh

install-dry:
	@$(ROOT)install.sh --dry-run

install-force:
	@$(ROOT)install.sh --force

wire:
	@$(ROOT)install.sh

uninstall:
	@$(ROOT)install.sh --uninstall
