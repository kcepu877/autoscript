#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

print_info "Running preflight checks..."

detect_os
print_success "OS detected: $OS_ID $OS_VER (family: $OS_FAMILY)"

detect_resources
print_success "Resources: ${RAM_MB} MB RAM, ${CPU_CORES} CPU (tier: ${TIER})"

if ! curl -s --max-time 5 https://www.google.com >/dev/null 2>&1; then
  print_error "No internet connectivity!"
  exit 1
fi
print_success "Internet connectivity OK"

if ! command -v systemctl >/dev/null 2>&1; then
  print_error "systemd not found"
  exit 1
fi
print_success "systemd OK"

print_success "Preflight checks passed."
