#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os
detect_resources

if [[ -f /etc/haproxy/haproxy.cfg ]] && systemctl is-active haproxy &>/dev/null; then
  print_warn "HAProxy already configured & running. Skipping."
  exit 0
fi

if [[ ! -f /etc/xray/xray.crt || ! -f /etc/xray/xray.key ]]; then
  print_error "/etc/xray/xray.crt or xray.key missing. Run module 08-nginx first."
  exit 1
fi

print_info "Installing HAProxy..."
$PKG_INSTALL haproxy >/dev/null 2>&1

mkdir -p /etc/haproxy
cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/haproxy.pem >/dev/null
chmod 600 /etc/haproxy/haproxy.pem

cat >/etc/haproxy/haproxy.cfg <<HA_EOF
global
    log /dev/log local0
    maxconn ${HA_MAXCONN}
    user haproxy
    group haproxy
    daemon
    tune.ssl.default-dh-param 2048

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5s
    timeout client 30m
    timeout server 30m

frontend http_in
    bind *:80
    mode tcp
    default_backend nginx_http

frontend tls_in
    bind *:443 ssl crt /etc/haproxy/haproxy.pem alpn h2,http/1.1
    mode tcp
    tcp-request inspect-delay 5s
    acl is_http req.payload(0,10) -m reg -i ^(GET|POST|HEAD|PUT|OPTIONS|DELETE|PATCH|TRACE|CONNECT)
    tcp-request content accept if { req.len gt 0 }
    use_backend nginx_http if is_http
    default_backend ssh_direct


backend nginx_http
    mode tcp
    server nginx_node 127.0.0.1:81 send-proxy check

backend ssh_direct
    mode tcp
    server dropbear_node 127.0.0.1:109 check
HA_EOF

systemctl enable haproxy --now >/dev/null 2>&1
check_service haproxy
print_success "Module 09-haproxy complete."
