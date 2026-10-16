#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os

print_info "Installing management menu (from repo)..."

REPO_OWNER="vvip"
REPO_NAME="autoscript"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_TARBALL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${REPO_BRANCH}.tar.gz"

$PKG_INSTALL tar gzip >/dev/null 2>&1

tmpdir=$(mktemp -d)
if ! wget -qO "$tmpdir/repo.tar.gz" "$REPO_TARBALL"; then
  print_error "Failed to download repo from $REPO_TARBALL"
  rm -rf "$tmpdir"
  exit 1
fi

tar -xzf "$tmpdir/repo.tar.gz" -C "$tmpdir"
srcdir=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -1)
[[ -z "$srcdir" ]] && srcdir="$tmpdir/${REPO_NAME}-${REPO_BRANCH}"

# Install shared libs
mkdir -p /usr/local/sbin/lib
if [[ -d "$srcdir/scripts/lib" ]]; then
  install -m 0644 "$srcdir/scripts/lib/"*.sh /usr/local/sbin/lib/ 2>/dev/null || true
fi

# Install command scripts
mkdir -p /usr/local/sbin/api
find "$srcdir/scripts" -maxdepth 2 -type f -name '*.sh' \
  ! -path '*/api/*' ! -path '*/lib/*' | while read -r file; do
  name=$(basename "$file" .sh)
  install -m 0755 "$file" "/usr/local/sbin/$name"
done

# Install API scripts
if [[ -d "$srcdir/scripts/api" ]]; then
  find "$srcdir/scripts/api" -maxdepth 1 -type f -name '*.sh' | while read -r file; do
    name=$(basename "$file" .sh)
    install -m 0755 "$file" "/usr/local/sbin/api/$name"
  done
fi

# Install RDNS presets
if [[ -d "$srcdir/scripts/rdns/presets" ]]; then
  mkdir -p /usr/local/sbin/rdns/presets /etc/rdns/presets
  cp -rf "$srcdir/scripts/rdns/presets/"*.json /usr/local/sbin/rdns/presets/ 2>/dev/null || true
  cp -rf "$srcdir/scripts/rdns/presets/"*.json /etc/rdns/presets/ 2>/dev/null || true
fi

# Install helper commands
[[ -f "$srcdir/install-api.sh" ]] && install -m 0755 "$srcdir/install-api.sh" /usr/local/sbin/install-api
[[ -f "$srcdir/uninstall-api.sh" ]] && install -m 0755 "$srcdir/uninstall-api.sh" /usr/local/sbin/uninstall-api
[[ -f "$srcdir/uninstall.sh" ]] && install -m 0755 "$srcdir/uninstall.sh" /usr/local/sbin/uninstall
if [[ -f /usr/local/sbin/lib/db.sh ]]; then
  . /usr/local/sbin/lib/db.sh
  db_init || true
  if [[ -d /etc/xray/database ]] && [[ -x /usr/local/sbin/db-migrate ]]; then
    /usr/local/sbin/db-migrate >/dev/null 2>&1 || true
  fi
  print_success "Database initialized."
fi

print_success "Module 15-menu complete."
