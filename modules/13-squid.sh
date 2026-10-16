#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

if systemctl is-active squid &>/dev/null; then
  print_success "Squid already running. Skipping."
  exit 0
fi

print_info "Installing & configuring Squid Proxy (Port 3128)..."
$PKG_INSTALL squid >/dev/null 2>&1

cat >/etc/squid/squid.conf <<'SQ_EOF'
acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl Safe_ports port 1194

http_access deny !Safe_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost
http_access deny to_localhost
http_access allow all

http_port 3128
coredump_dir /var/spool/squid

refresh_pattern ^ftp:144020%10080
refresh_pattern -i (/cgi-bin/|\?) 00%0
refresh_pattern .020%4320
SQ_EOF

systemctl enable squid >/dev/null 2>&1
squid -z >/dev/null 2>&1 || true
systemctl restart squid >/dev/null 2>&1

# Open firewall
if [[ "$OS_FAMILY" == "debian" ]]; then
  ufw allow 3128/tcp >/dev/null 2>&1 || true
elif [[ "$OS_FAMILY" == "rhel" ]]; then
  firewall-cmd --zone=public --add-port=3128/tcp --permanent >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

check_service squid || print_warn "Squid not active."
print_success "Module 13-squid complete."
