#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

if systemctl is-active noobzvpns &>/dev/null; then
  print_success "NoobzVPN already running. Skipping."
  exit 0
fi

print_info "Installing & configuring NoobzVPN Server..."
mkdir -p /etc/noobzvpns
chmod 755 /etc/noobzvpns

arch=$(uname -m)
bin_url="https://github.com/noobz-id/noobzvpns/raw/master/noobzvpns.x86-64"
[[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && bin_url="https://github.com/noobz-id/noobzvpns/raw/master/noobzvpns.aarch64"

curl -sSL --connect-timeout 10 -o /usr/bin/noobzvpns "$bin_url" 2>/dev/null || \
  wget -q -O /usr/bin/noobzvpns "$bin_url" 2>/dev/null || true
chmod +x /usr/bin/noobzvpns

if [[ ! -x /usr/bin/noobzvpns ]]; then
  print_warn "Failed to download noobzvpns binary. Skipping."
  exit 0
fi

# SSL cert (reuse xray cert kalau ada)
if [[ -f /etc/xray/xray.key && -f /etc/xray/xray.crt ]]; then
  cp -f /etc/xray/xray.key /etc/noobzvpns/key.pem
  cp -f /etc/xray/xray.crt /etc/noobzvpns/cert.pem
else
  openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/CN=noobzvpns" \
    -keyout /etc/noobzvpns/key.pem -out /etc/noobzvpns/cert.pem >/dev/null 2>&1 || true
fi
chmod 600 /etc/noobzvpns/key.pem /etc/noobzvpns/cert.pem 2>/dev/null || true

if [[ ! -f /etc/noobzvpns/db_user.json ]]; then
  cat >/etc/noobzvpns/db_user.json <<'DB_EOF'
{
  "version": 331,
  "users": {}
}
DB_EOF
  chmod 600 /etc/noobzvpns/db_user.json
fi

cat >/etc/noobzvpns/config.toml <<'CFG_EOF'
# NoobzVpn-Server Configuration File
# (c) Noobz-ID Software

[tcp_plain]
local_host = ["8585"]

[tcp_ssl]
tls_version = "AUTO"
key_pem = "/etc/noobzvpns/key.pem"
cert_pem = "/etc/noobzvpns/cert.pem"

[client]
ip_version = "AUTO"
tcp_initial_timeout = 30
resolv_conf = "/etc/resolv.conf"
identifier = "vvip"
banner = "You are connected to noobzvpn-server"
tcp_http_response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"

[remote]
tcp_connect_timeout = 30
tcp_idle_timeout = 900
udp_connect_timeout = 30
udp_idle_timeout = 60
udp_dns_timeout = 10

[database]
database_monitor_timer = 30
device_timeout = 5

[runtime]
worker_threads = 0
CFG_EOF

chmod 600 /etc/noobzvpns/config.toml

cat >/etc/systemd/system/noobzvpns.service <<'SVC'
[Unit]
Description=NoobzVpn-Server
Wants=network-online.target
After=network.target network-online.target

[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
User=root
Type=simple
WorkingDirectory=/etc/noobzvpns
TimeoutStopSec=1
LimitNOFILE=infinity
ExecStart=/usr/bin/noobzvpns start-server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable noobzvpns >/dev/null 2>&1
systemctl restart noobzvpns >/dev/null 2>&1
check_service "noobzvpns" || print_warn "NoobzVpn service not active."

print_success "Module 14-noobz complete."
