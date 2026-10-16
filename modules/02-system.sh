#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os
detect_resources

print_info "Configuring SSH Access..."
cd /etc/ssh
sed -i 's/#Port 22/Port 22/g' sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' sshd_config
grep -q "Port 3303" sshd_config || echo "Port 3303" >>sshd_config
cd -
systemctl daemon-reload
systemctl restart sshd
print_success "SSH Hardening complete (Port 22, 3303)."

print_info "Registering nologin shell in /etc/shells..."
touch /etc/shells
for s in /usr/sbin/nologin /sbin/nologin /bin/false; do
  [[ -e "$s" ]] && { grep -qxF "$s" /etc/shells || echo "$s" >>/etc/shells; }
done
print_success "nologin shell registered."

print_info "Configuring rsyslog for $AUTH_LOG..."
if [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL rsyslog || true
  if ! grep -rqs 'authpriv\.\*' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
    echo "authpriv.*    $AUTH_LOG" >/etc/rsyslog.d/00-autoscript-secure.conf
  fi
  systemctl enable rsyslog --now
  systemctl restart rsyslog
else
  $PKG_INSTALL rsyslog || true
  systemctl enable rsyslog --now 2>/dev/null || true
  systemctl restart rsyslog 2>/dev/null || true
fi
print_success "rsyslog active (authpriv -> $AUTH_LOG)."

print_info "Preparing system directories..."
mkdir -p /etc/xray/limit/ip/{ssh,vless,trojan,vmess}
mkdir -p /etc/xray/limit/quota/{vless,trojan,vmess}
mkdir -p /etc/xray/limit/database/{ssh,vless,trojan,vmess}
mkdir -p /etc/xray/usage/quota/{vless,trojan,vmess}
mkdir -p /etc/xray/recovery/{ssh,vless,trojan,vmess,noobz}
print_success "Directories created."

print_info "Applying network tuning for ${TIER} tier..."
cat >/etc/sysctl.conf <<SYSCTL_EOF
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = ${TCP_RMEM_MAX}
net.core.wmem_max = ${TCP_WMEM_MAX}
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_rmem = 4096 87380 ${TCP_RMEM_MAX}
net.ipv4.tcp_wmem = 4096 65536 ${TCP_WMEM_MAX}
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_max_syn_backlog = 8192
fs.file-max = ${FILE_MAX}
SYSCTL_EOF
sysctl -p >/dev/null 2>&1
print_success "Network stack optimized."

print_success "Module 02-system complete."
