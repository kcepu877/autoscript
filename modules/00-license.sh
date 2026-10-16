#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

IZIN_URL="https://raw.githubusercontent.com/kcepu877/izin/main/ip"

print_info "Verifying license..."

VPS_IP=$(curl -sS --max-time 10 ipv4.icanhazip.com 2>/dev/null || wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null || curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "")

if [[ -z "$VPS_IP" ]]; then
  print_error "Gagal ambil IP VPS"
  exit 1
fi
print_info "VPS IP: $VPS_IP"

DATE_NOW=$(date +"%Y-%m-%d")

IZIN_LIST=$(curl -sS --max-time 10 "$IZIN_URL" 2>/dev/null || wget -qO- --timeout=10 "$IZIN_URL" 2>/dev/null || echo "")

if [[ -z "$IZIN_LIST" ]]; then
  print_error "Gagal fetch izin list"
  exit 1
fi

MATCH=$(echo "$IZIN_LIST" | grep -w "$VPS_IP" || true)

if [[ -z "$MATCH" ]]; then
  print_error "404 NOT FOUND — IP TIDAK TERDAFTAR"
  print_error "VPS IP: $VPS_IP"
  print_error "WhatsApp: wa.me/6287861167414"
  exit 1
fi

USERNAME=$(echo "$MATCH" | awk '{print $2}')
EXPIRY=$(echo "$MATCH" | awk '{print $3}')

if [[ "$DATE_NOW" < "$EXPIRY" ]]; then
  print_success "License valid"
else
  print_error "LICENSE EXPIRED"
  print_error "Expiry: $EXPIRY | Today: $DATE_NOW"
  print_error "WhatsApp: wa.me/6287861167414"
  exit 1
fi

mkdir -p /usr/bin
echo "$USERNAME" > /usr/bin/user
echo "$EXPIRY" > /usr/bin/e
chmod 644 /usr/bin/user /usr/bin/e

print_success "LICENSE OK — User: $USERNAME, Expiry: $EXPIRY"
