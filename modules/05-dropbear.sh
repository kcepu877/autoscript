#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

if systemctl is-active dropbear &>/dev/null; then
  print_success "Dropbear is already running. Skipping."
  exit 0
fi

print_info "Compiling Dropbear 2019.78..."

if [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL "$PKG_GROUP_BUILD" >/dev/null 2>&1
  $PKG_INSTALL zlib-devel wget bzip2 >/dev/null 2>&1
elif [[ "$OS_FAMILY" == "debian" ]]; then
  $PKG_INSTALL build-essential zlib1g-dev wget bzip2 >/dev/null 2>&1
fi

cd /usr/local/src
wget -q --no-check-certificate https://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2 ||
  wget -q --no-check-certificate https://dropbear.nl/mirror/releases/dropbear-2019.78.tar.bz2
tar xjf dropbear-2019.78.tar.bz2 >/dev/null 2>&1
cd dropbear-2019.78
./configure --prefix=/usr --sysconfdir=/etc/dropbear >/dev/null 2>&1
make -j"$(nproc)" >/dev/null 2>&1
make install >/dev/null 2>&1
cd ..
rm -fr dropbear*

cat >/etc/systemd/system/dropbear.service <<'SVC_EOF'
[Unit]
Description=Dropbear SSH Server
After=network.target rsyslog.service

[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -F -p 109 -b /etc/issue.net -r /etc/dropbear/dropbear_rsa_host_key -W 65536
Restart=always

[Install]
WantedBy=multi-user.target
SVC_EOF

mkdir -p /etc/dropbear
[ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
echo "Enterprise VPN Server" >/etc/issue.net
systemctl daemon-reload
systemctl enable dropbear --now >/dev/null 2>&1
check_service dropbear
print_success "Dropbear installed and running on port 109."

print_success "Module 05-dropbear complete."
