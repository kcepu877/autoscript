#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

WEB_DIR="/var/www/html/vvip/openvpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

DOMAIN_FILE="/etc/xray/domain"
if [[ -f "$DOMAIN_FILE" ]]; then DOMAIN=$(cat "$DOMAIN_FILE"); else DOMAIN="localhost"; fi

if [[ -f /etc/openvpn/server/server-tcp-1194.conf || -f /etc/openvpn/server.conf ]]; then
  print_warn "OpenVPN already installed. Skipping."
  exit 0
fi

print_info "Installing OpenVPN..."
if [[ "$OS_FAMILY" == "debian" ]]; then
  echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
  echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
  $PKG_INSTALL openvpn easy-rsa iptables-persistent >/dev/null 2>&1
elif [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL openvpn easy-rsa iptables-services >/dev/null 2>&1
fi

mkdir -p "$WEB_DIR" "$EASYRSA_DIR" /etc/openvpn/server
cp -r "$EASYRSA_SRC"/* "$EASYRSA_DIR/" 2>/dev/null || true
cd "$EASYRSA_DIR"

export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="AutoscriptCA"
export EASYRSA_REQ_COUNTRY="ID"
export EASYRSA_REQ_PROVINCE="Jakarta"
export EASYRSA_REQ_CITY="Jakarta"
export EASYRSA_REQ_ORG="vvip"
export EASYRSA_REQ_EMAIL="admin@${DOMAIN}"
export EASYRSA_REQ_OU="VPN"
export EASYRSA_ALGO="rsa"
export EASYRSA_KEY_SIZE=2048

./easyrsa init-pki >/dev/null 2>&1
./easyrsa --batch build-ca nopass >/dev/null 2>&1
./easyrsa --batch gen-req server nopass >/dev/null 2>&1
./easyrsa --batch sign-req server server >/dev/null 2>&1
./easyrsa gen-dh >/dev/null 2>&1
if ! openvpn --genkey --secret ta.key >/dev/null 2>&1; then
  openvpn --genkey secret ta.key >/dev/null 2>&1 || { print_error "Failed to generate ta.key"; exit 1; }
fi

cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem ta.key /etc/openvpn/server/

ovpn_ok=1
for f in ca.crt server.crt server.key dh.pem ta.key; do
  [[ ! -s "/etc/openvpn/server/$f" ]] && { print_error "Missing: $f"; ovpn_ok=0; }
done
[[ $ovpn_ok -eq 1 ]] && print_success "OpenVPN PKI generated."

PLUGIN_PAM="${OVPN_PLUGIN_DIR}/openvpn-plugin-auth-pam.so"

if [[ "$OS_FAMILY" == "debian" ]]; then
  SERVER_CONF="/etc/openvpn/server.conf"
else
  SERVER_CONF="/etc/openvpn/server/server-tcp-1194.conf"
fi

cat >"$SERVER_CONF" <<OVPN_EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0
topology subnet
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo no
push "comp-lzo no"
cipher AES-128-GCM
ncp-ciphers AES-128-GCM:AES-256-GCM
auth SHA256
plugin $PLUGIN_PAM login
verify-client-cert none
username-as-common-name
persist-key
persist-tun
status openvpn-status-tcp.log
verb 3
OVPN_EOF

CA_DATA=$(cat /etc/openvpn/server/ca.crt)
TA_DATA=$(cat /etc/openvpn/server/ta.key)
MYIP=$(curl -s --max-time 5 http://checkip.amazonaws.com 2>/dev/null || hostname -I | awk '{print $1}')

cat >"$WEB_DIR/tcp.ovpn" <<OVPN_EOF
client
dev tun
proto tcp
remote $MYIP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
key-direction 1
setenv CLIENT_CERT 0
setenv FRIENDLY_NAME "OpenVPN TCP"
socket-flags TCP_NODELAY
cipher AES-128-GCM
auth SHA256
auth-user-pass
comp-lzo no
verb 3
<ca>
$CA_DATA
</ca>
<tls-auth>
$TA_DATA
</tls-auth>
OVPN_EOF

echo 1 >/proc/sys/net/ipv4/ip_forward
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf

if [[ "$OS_FAMILY" == "debian" ]]; then
  ufw allow 1194/tcp >/dev/null 2>&1 || true
  sed -i 's|^DEFAULT_FORWARD_POLICY=.*|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw 2>/dev/null || true
  ufw reload >/dev/null 2>&1 || true
elif [[ "$OS_FAMILY" == "rhel" ]]; then
  firewall-cmd --zone=public --add-port=1194/tcp --permanent >/dev/null 2>&1 || true
  firewall-cmd --add-masquerade --permanent >/dev/null 2>&1 || true
  firewall-cmd --reload >/dev/null 2>&1 || true
fi

if [[ "$OS_FAMILY" == "debian" ]]; then
  systemctl enable openvpn@server >/dev/null 2>&1
  systemctl restart openvpn@server >/dev/null 2>&1
  check_service "openvpn@server" || print_warn "OpenVPN not active."
else
  systemctl enable openvpn-server@server-tcp-1194 >/dev/null 2>&1
  systemctl restart openvpn-server@server-tcp-1194 >/dev/null 2>&1
  check_service "openvpn-server@server-tcp-1194" || print_warn "OpenVPN not active."
fi

print_success "Module 12-openvpn complete."
