#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

print_info "Initializing account database (SQLite)..."

DB_LIB="/usr/local/sbin/lib/db.sh"
if [[ -f "$DB_LIB" ]]; then
  # shellcheck disable=SC1090
  . "$DB_LIB"
  db_init
  if [[ -d /etc/xray/database ]] && [[ -x /usr/local/sbin/db-migrate ]]; then
    /usr/local/sbin/db-migrate >/dev/null 2>&1 || true
  fi
  print_success "Database initialized at /etc/xray/xray.db."
else
  print_warn "Database library missing: $DB_LIB"
  print_warn "Menu may not function until menu scripts are installed."
fi

print_success "Module 04-database complete."
