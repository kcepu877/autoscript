#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

print_info "Updating system repositories..."

if [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL epel-release || true
  $PKG_UPDATE
  $PKG_INSTALL wget curl openssl sudo binutils coreutils gnupg2 bc \
    vnstat htop lsof jq sqlite tar gzip python3 ruby rubygems
  gem install lolcat
elif [[ "$OS_FAMILY" == "debian" ]]; then
  $PKG_UPDATE
  $PKG_INSTALL wget curl openssl sudo binutils coreutils gnupg2 bc \
    vnstat htop lsof jq sqlite3 tar gzip python3 python3-pip ruby ruby-dev
  gem install lolcat
fi

systemctl enable vnstat --now
systemctl restart vnstat
print_success "Core packages installed."

print_info "Optimizing DNS resolution..."
if [[ -L /etc/resolv.conf ]]; then
  print_warn "/etc/resolv.conf is a symlink (systemd-resolved). Using systemd-resolved."
  mkdir -p /etc/systemd/resolved.conf.d
  cat >/etc/systemd/resolved.conf.d/dns.conf <<'DNS_EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
DNS_EOF
  systemctl restart systemd-resolved 2>/dev/null || true
else
  echo "nameserver 8.8.8.8" >/etc/resolv.conf
  echo "nameserver 1.1.1.1" >>/etc/resolv.conf
fi
print_success "DNS configured."

print_success "Module 01-package complete."
