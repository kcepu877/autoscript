#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

if [[ -f /etc/xray/config.json ]]; then
  print_warn "Xray already configured. Skipping."
  exit 0
fi

print_info "Synchronizing Xray-core release 25.10.15..."
mkdir -p /usr/local/share/xray
wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
chmod +x /usr/local/share/xray/*

print_info "Generating Xray configuration..."
mkdir -p /etc/xray
chmod 700 /etc/xray
uuid=$(cat /proc/sys/kernel/random/uuid)

cat >/etc/xray/config.json <<XRAY_EOF
{
  "log": {"access": "/var/log/xray/access.log", "loglevel": "info"},
  "api": {"tag": "api", "services": ["StatsService"]},
  "stats": {},
  "policy": {
    "levels": {"0": {"statsUserDownlink": true, "statsUserUplink": true}},
    "system": {"statsInboundUplink": true, "statsInboundDownlink": true,
               "statsOutboundUplink": true, "statsOutboundDownlink": true}
  },
  "inbounds": [
    {"tag": "api", "listen": "127.0.0.1", "port": 10085,
     "protocol": "dokodemo-door", "settings": {"address": "127.0.0.1"}},
    {"tag": "vless-ws", "listen": "127.0.0.1", "port": 1, "protocol": "vless",
     "settings": {"decryption": "none", "clients": [{"id": "${uuid}"}]},
     "sniffing": {"enabled": true, "destOverride": ["http","tls","quic"]},
     "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}},
    {"tag": "trojan-ws", "listen": "127.0.0.1", "port": 2, "protocol": "trojan",
     "settings": {"clients": [{"password": "${uuid}"}]},
     "sniffing": {"enabled": true, "destOverride": ["http","tls","quic"]},
     "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}},
    {"tag": "vmess-ws", "listen": "127.0.0.1", "port": 3, "protocol": "vmess",
     "settings": {"clients": [{"id": "${uuid}", "alterId": 0}]},
     "sniffing": {"enabled": true, "destOverride": ["http","tls","quic"]},
     "streamSettings": {"network": "ws", "wsSettings": {"path": "/"}}}
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "blocked"}
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {"type": "field", "inboundTag": ["api"], "outboundTag": "api"},
      {"type": "field", "outboundTag": "blocked", "protocol": ["bittorrent"]}
    ]
  }
}
XRAY_EOF

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u nobody --version 25.10.15 >/dev/null 2>&1

mkdir -p /var/log/xray
touch /var/log/xray/{access,error}.log
chown -R root:root /var/log/xray
chmod 644 /var/log/xray/*.log

rm -f /etc/systemd/system/xray.service /etc/systemd/system/xray@.service 2>/dev/null
rm -rf /etc/systemd/system/xray.service.d 2>/dev/null

cat >/etc/systemd/system/xray.service <<'SVC_EOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
LimitMEMLOCK=infinity
Nice=-10
PrivateTmp=true
ProtectSystem=false
ProtectHome=false

[Install]
WantedBy=multi-user.target
SVC_EOF

systemctl daemon-reload
systemctl enable xray --now >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
check_service xray
print_success "Xray Core initialized."

print_success "Module 07-xray complete."
