#!/bin/bash
# ========================================================
# Project: Autoscript VPN by kcepu877
# Description: Main Installer (Orchestrator)
# Version: 5.4.0-modular
# Repository: https://github.com/kcepu877/autoscript
# ========================================================
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INSTALL_DIR

. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

if [[ "$EUID" -ne 0 ]]; then
  print_error "This script must be run as root!"
  exit 1
fi

print_header
print_info "Starting installation from: $INSTALL_DIR"
print_info "Modules will run in order. Abort on first failure."
echo ""

# --- Daftar modul (urutan penting!) ---
MODULES=(
  00-preflight
  01-package
  02-system
  03-firewall
  04-database
  05-dropbear
  06-ssh-ws
  07-xray
  08-nginx
  09-haproxy
  10-timers
  11-swap
  12-openvpn
  13-squid
  14-noobz
  15-menu
  16-api
  99-finish
)

FAILED=0
for mod in "${MODULES[@]}"; do
  MODULE_FILE="$INSTALL_DIR/modules/${mod}.sh"
  if [[ ! -f "$MODULE_FILE" ]]; then
    print_error "Module not found: $mod"
    FAILED=1
    break
  fi
  echo ""
  print_info "╔══════════════════════════════════════════════╗"
  print_info "║  Running module: $mod"
  print_info "╚══════════════════════════════════════════════╝"
  if ! bash "$MODULE_FILE"; then
    print_error "Module FAILED: $mod"
    print_error "Installation aborted. Check output above."
    FAILED=1
    break
  fi
  print_success "Module OK: $mod"
done

echo ""
if [[ $FAILED -eq 0 ]]; then
  print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print_success "  ALL MODULES COMPLETED SUCCESSFULLY"
  print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  print_info "Run 'menu' to open the management panel."
else
  print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print_error "  INSTALLATION FAILED"
  print_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi
