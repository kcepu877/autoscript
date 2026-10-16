#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

print_info "Hardening Firewall..."

if [[ "$OS_FAMILY" == "debian" ]]; then
  $PKG_INSTALL ufw >/dev/null 2>&1
  ufw --force reset >/dev/null 2>&1
  ufw default deny incoming >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1

  ufw allow 22/tcp   >/dev/null 2>&1
  ufw allow 3303/tcp >/dev/null 2>&1
  ufw allow 109/tcp  >/dev/null 2>&1
  ufw allow 80/tcp   >/dev/null 2>&1
  ufw allow 443/tcp  >/dev/null 2>&1
  ufw allow 7300/udp >/dev/null 2>&1
  ufw allow 1194/tcp >/dev/null 2>&1
  ufw allow 8585/tcp >/dev/null 2>&1

  ufw --force enable >/dev/null 2>&1
  print_success "Firewall locked down (ufw allowlist)."

elif [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL firewalld >/dev/null 2>&1
  systemctl enable firewalld --now >/dev/null 2>&1

  firewall-cmd --set-default-zone=public >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --set-target=default >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --remove-port=1-65535/tcp >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --remove-port=1-65535/udp >/dev/null 2>&1

  firewall-cmd --permanent --zone=public --add-port=22/tcp   >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=3303/tcp >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=109/tcp  >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=80/tcp   >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=443/tcp  >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=7300/udp >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=1194/tcp >/dev/null 2>&1
  firewall-cmd --permanent --zone=public --add-port=8585/tcp >/dev/null 2>&1

  firewall-cmd --reload >/dev/null 2>&1
  print_success "Firewall locked down (firewalld allowlist)."

  if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce 2>/dev/null)" != "Disabled" ]]; then
    print_info "Configuring SELinux booleans..."
    $PKG_INSTALL policycoreutils >/dev/null 2>&1 || true
    setsebool -P httpd_can_network_connect 1 2>/dev/null
    setsebool -P httpd_can_network_connect_db 1 2>/dev/null
    setsebool -P httpd_can_network_relay 1 2>/dev/null
    print_success "SELinux booleans applied."
  else
    print_info "SELinux disabled or not present; skipping."
  fi
fi

print_info "Internal services remain bound to 127.0.0.1."
print_success "Module 03-firewall complete."
