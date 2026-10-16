#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

print_info "Building and installing API server..."

# Cek apakah install-api.sh sudah ada (dari module 15-menu)
if [[ -x /usr/local/sbin/install-api ]]; then
  print_info "Running /usr/local/sbin/install-api..."
  if /usr/local/sbin/install-api; then
    print_success "API server installed via install-api."
    exit 0
  else
    print_warn "install-api failed. Trying manual build..."
  fi
fi

# Fallback: manual build kalau source Go tersedia
# Cek di folder script_dir/files
script_dir="$INSTALL_DIR"
API_DIR="$script_dir/files"

if [[ ! -d "$API_DIR" ]]; then
  print_warn "API source directory not found: $API_DIR"
  print_warn "Skipping API server. Install manually with 'install-api' later."
  exit 0
fi

if ! command -v go &>/dev/null; then
  print_info "Installing Go..."
  if [[ "$(source /etc/os-release; echo $ID)" == "ubuntu" || "$(source /etc/os-release; echo $ID)" == "debian" ]]; then
    apt install -y golang-go 2>/dev/null || apt install -y golang
  else
    dnf install -y golang
  fi
fi

cd "$API_DIR"
go mod tidy
CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/api-server ./cmd/server/main.go
chmod +x /usr/local/bin/api-server
ln -sf /usr/local/bin/api-server /usr/local/bin/autoscript-api

mkdir -p /etc/api
chmod 700 /etc/api

if [[ -f "$API_DIR/api-server.service" ]]; then
  cp "$API_DIR/api-server.service" /etc/systemd/system/api-server.service
  chmod 644 /etc/systemd/system/api-server.service
  systemctl daemon-reload
  systemctl enable api-server --now
fi

print_success "Module 16-api complete."
