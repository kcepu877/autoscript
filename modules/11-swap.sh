#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_resources

if [[ -f /swapfile ]]; then
  print_success "Swapfile already exists. Skipping."
  exit 0
fi

print_info "Configuring dynamic swap (RAM-aware)..."

FREE_DISK=$(df -k / | awk 'NR==2 {print $4}')
if ((RAM_MB <= 1280)); then SWAP_SIZE_GB=2
elif ((RAM_MB <= 2560)); then SWAP_SIZE_GB=2
elif ((RAM_MB <= 5120)); then SWAP_SIZE_GB=4
else SWAP_SIZE_GB=4; fi

NEED_KB=$(((SWAP_SIZE_GB * 1024 * 1024) + (5 * 1024 * 1024)))
while ((SWAP_SIZE_GB > 0)) && ((FREE_DISK < NEED_KB)); do
  SWAP_SIZE_GB=$((SWAP_SIZE_GB - 1))
  NEED_KB=$(((SWAP_SIZE_GB * 1024 * 1024) + (5 * 1024 * 1024)))
done

if ((SWAP_SIZE_GB > 0)); then
  swapoff -a >/dev/null 2>&1 || true
  sed -i '/swapfile/d' /etc/fstab >/dev/null 2>&1 || true
  rm -f /swapfile >/dev/null 2>&1 || true

  if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "${SWAP_SIZE_GB}G" /swapfile
  else
    dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024))
  fi

  chmod 600 /swapfile
  mkswap /swapfile >/dev/null 2>&1
  swapon /swapfile >/dev/null 2>&1
  echo "/swapfile none swap defaults 0 0" >>/etc/fstab

  if ((RAM_MB <= 1280)); then SWAPPINESS=60; else SWAPPINESS=15; fi
  sysctl -w vm.swappiness=${SWAPPINESS} >/dev/null 2>&1
  grep -q "vm.swappiness" /etc/sysctl.conf || echo "vm.swappiness=${SWAPPINESS}" >>/etc/sysctl.conf

  print_success "${SWAP_SIZE_GB}GB swap active (swappiness=${SWAPPINESS})."
else
  print_warn "Not enough free disk for swapfile. Skipped."
fi

print_success "Module 11-swap complete."
