#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

print_info "Configuring systemd timers..."

cat >/etc/systemd/system/autoexpire.service <<'SVC'
[Unit]
Description=Auto-expire accounts (all protocols)
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/expire-all
SVC

cat >/etc/systemd/system/autoexpire.timer <<'TMR'
[Unit]
Description=Run account auto-expire every minute
[Timer]
OnBootSec=60
OnUnitActiveSec=60
AccuracySec=15s
Persistent=true
[Install]
WantedBy=timers.target
TMR

cat >/etc/systemd/system/limit-ip-ssh.service <<'SVC'
[Unit]
Description=SSH IP-limit enforcement
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/limit-ip-ssh
SVC

cat >/etc/systemd/system/limit-ip-ssh.timer <<'TMR'
[Unit]
Description=Run SSH IP-limit enforcement every 2 minutes
[Timer]
OnBootSec=90
OnUnitActiveSec=120
AccuracySec=15s
Persistent=true
[Install]
WantedBy=timers.target
TMR

cat >/etc/systemd/system/backup.service <<'SVC'
[Unit]
Description=Account/database backup
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup
SVC

cat >/etc/systemd/system/backup.timer <<'TMR'
[Unit]
Description=Run backup hourly
[Timer]
OnCalendar=hourly
Persistent=true
[Install]
WantedBy=timers.target
TMR

cat >/etc/systemd/system/fixlog.service <<'SVC'
[Unit]
Description=Log maintenance
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/fixlog
SVC

cat >/etc/systemd/system/fixlog.timer <<'TMR'
[Unit]
Description=Run log maintenance daily
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
TMR

systemctl daemon-reload
systemctl enable --now autoexpire.timer limit-ip-ssh.timer backup.timer fixlog.timer 2>/dev/null || true

print_warn "Timers enabled. Services will fail until menu scripts (15-menu) are installed."
print_success "Module 10-timers complete."
