#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

SSHWS_VERSION="v1.3.1"

if systemctl is-active ssh-ws &>/dev/null; then
  print_success "SSH-WebSocket proxy already running. Skipping."
  exit 0
fi

print_info "Installing SSH-WebSocket proxy (GO-TUNNEL PRO ${SSHWS_VERSION})..."

# --- Detect architecture ---
case "$(uname -m)" in
  x86_64)  arch="linux-amd64" ;;
  aarch64) arch="linux-arm64" ;;
  armv7l)  arch="linux-armv7" ;;
  *) print_error "Unsupported arch: $(uname -m)"; exit 1 ;;
esac

# --- Coba beberapa format asset name (dengan/tanpa 'v') ---
base="https://github.com/vvip/websocket-proxy/releases/download/${SSHWS_VERSION}"
tmp="$(mktemp -d)"

# Kandidat nama asset (siapa tahu formatnya beda)
CANDIDATES=(
  "ssh-ws-${SSHWS_VERSION}-${arch}.tar.gz"       # ssh-ws-v1.3.1-linux-amd64.tar.gz
  "ssh-ws-${SSHWS_VERSION#v}-${arch}.tar.gz"     # ssh-ws-1.3.1-linux-amd64.tar.gz
  "ssh-ws-${arch}.tar.gz"                         # ssh-ws-linux-amd64.tar.gz
)

asset=""
for candidate in "${CANDIDATES[@]}"; do
  print_info "Trying: $candidate"
  if wget -qO "${tmp}/ssh-ws.tar.gz" "${base}/${candidate}"; then
    asset="$candidate"
    print_success "Downloaded: $candidate"
    break
  fi
done

if [[ -z "$asset" ]]; then
  print_error "Failed to download ssh-ws for ${arch}."
  print_error "Tried: ${CANDIDATES[*]}"
  print_error "Check releases: https://github.com/vvip/websocket-proxy/releases"
  rm -rf "$tmp"
  exit 1
fi

# --- Checksum verification (best effort, jangan fatal kalau tidak match) ---
if wget -qO "${tmp}/checksums.txt" "${base}/checksums.txt" 2>/dev/null; then
  # Ambil checksum untuk asset kita (handle spasi 1 atau 2)
  want=$(grep -E "[[:space:]]+${asset}\$" "${tmp}/checksums.txt" 2>/dev/null | awk '{print $1}' | head -1 || true)
  if [[ -n "$want" ]]; then
    got=$(sha256sum "${tmp}/ssh-ws.tar.gz" | awk '{print $1}')
    if [[ "$want" != "$got" ]]; then
      print_error "Checksum mismatch for ${asset}!"
      print_error "  expected: $want"
      print_error "  got     : $got"
      rm -rf "$tmp"
      exit 1
    fi
    print_success "Checksum verified."
  else
    print_warn "No checksum entry found for ${asset} — skipping verification."
  fi
else
  print_warn "checksums.txt not available — skipping verification."
fi

# --- Extract archive ---
if ! tar -xzf "${tmp}/ssh-ws.tar.gz" -C "$tmp" >/dev/null 2>&1; then
  print_error "Failed to extract archive."
  rm -rf "$tmp"
  exit 1
fi

# --- Find binary in extracted files ---
bin=$(find "$tmp" -maxdepth 2 -type f -name 'ssh-ws*' \
  ! -name '*.tar.gz' ! -name '*.sha256' ! -name 'checksums.txt' | head -1 || true)
if [[ -z "$bin" ]]; then
  print_error "ssh-ws binary not found in archive."
  print_info "Archive contents:"
  tar -tzf "${tmp}/ssh-ws.tar.gz" | head -20
  rm -rf "$tmp"
  exit 1
fi
print_success "Binary found: $(basename "$bin")"

install -m 0755 "$bin" /usr/local/bin/ssh-ws
rm -rf "$tmp"

# --- Write systemd unit ---
cat >/etc/systemd/system/ssh-ws.service <<SVC_EOF
[Unit]
Description=GO-TUNNEL PRO SSH WebSocket Proxy
After=network.target dropbear.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/ssh-ws -b 0.0.0.0 -p 8888 -t 127.0.0.1:109 \\
  -l /var/log/ssh-ws.log --auth-log ${AUTH_LOG} --api-port 8081
Restart=always
RestartSec=5
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
SVC_EOF

systemctl daemon-reload
systemctl enable ssh-ws --now >/dev/null 2>&1
check_service ssh-ws
print_success "SSH-WebSocket proxy running on port 8888 (-> SSH 109)."
print_success "Module 06-ssh-ws complete."
