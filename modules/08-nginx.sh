#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"
detect_os
detect_resources

DOMAIN_FILE="/etc/xray/domain"
if [[ -f "$DOMAIN_FILE" ]]; then
  DOMAIN=$(cat "$DOMAIN_FILE")
  print_info "Domain: $DOMAIN"
else
  print_warn "Domain not set."
  read -rp "Input Domain Name: " DOMAIN
  [[ -z "$DOMAIN" ]] && { print_error "Domain cannot be empty."; exit 1; }
  mkdir -p /etc/xray
  echo "$DOMAIN" > "$DOMAIN_FILE"
fi

if [[ -f /etc/nginx/vvip.conf ]]; then
  print_warn "Nginx already configured. Skipping."
  exit 0
fi

print_info "Installing nginx..."
$PKG_INSTALL nginx >/dev/null 2>&1

print_info "Obtaining SSL Certificate for $DOMAIN..."
if [[ "$OS_FAMILY" == "debian" ]]; then
  $PKG_INSTALL socat lsof >/dev/null 2>&1
  if [[ "$OS_ID" == "ubuntu" && ( "$OS_VER" == "20.04" || "$OS_VER" == "22.04" ) ]]; then
    $PKG_INSTALL snapd >/dev/null 2>&1
    snap install --classic certbot >/dev/null 2>&1 || true
    ln -sf /snap/bin/certbot /usr/bin/certbot 2>/dev/null || true
  else
    $PKG_INSTALL certbot >/dev/null 2>&1
  fi
elif [[ "$OS_FAMILY" == "rhel" ]]; then
  $PKG_INSTALL socat lsof certbot >/dev/null 2>&1
fi

systemctl stop httpd nginx 2>/dev/null || true
certbot certonly --standalone --preferred-challenges http --agree-tos \
  --email "www@${DOMAIN}" -d "$DOMAIN" --non-interactive || true

if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && \
      -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/xray/xray.crt
  cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/xray/xray.key
  chmod 644 /etc/xray/xray.crt
  chmod 600 /etc/xray/xray.key
  print_success "Certificates issued."
else
  print_error "Certificate issuance failed for $DOMAIN."
  print_warn "Check DNS A record & port 80."
  exit 1
fi

print_info "Configuring nginx..."
cat >/etc/nginx/nginx.conf <<NGX_EOF
user ${NGINX_USER};
worker_processes auto;
worker_cpu_affinity auto;
worker_rlimit_nofile ${NGX_RLIMIT};

events {
    worker_connections ${NGX_CONN};
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300;
    keepalive_requests 10000;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log off;
    error_log /var/log/nginx/error.log crit;
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    include /etc/nginx/vvip.conf;
}
NGX_EOF

cat >/etc/nginx/vvip.conf <<NGX_EOF
upstream vmess_ws { server 127.0.0.1:3; keepalive 32; }
upstream ssh_ws   { server 127.0.0.1:8888; keepalive 32; }
upstream vless_ws { server 127.0.0.1:1; keepalive 32; }
upstream trojan_ws { server 127.0.0.1:2; keepalive 32; }

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

map \$http_sec_websocket_key \$root_upstream {
    default  127.0.0.1:8888;
    "~.+"    127.0.0.1:3;
}

server {
    listen 127.0.0.1:81 default_server proxy_protocol;
    server_name ${DOMAIN};

    location /vless {
        if (\$http_upgrade != "websocket") { return 444; }
        proxy_pass http://vless_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 7d;
        proxy_send_timeout 7d;
        proxy_buffering off;
    }

    location /vmess {
        if (\$http_upgrade != "websocket") { return 444; }
        proxy_pass http://vmess_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_read_timeout 7d;
        proxy_send_timeout 7d;
        proxy_buffering off;
    }

    location /trojan {
        if (\$http_upgrade != "websocket") { return 444; }
        proxy_pass http://trojan_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_read_timeout 7d;
        proxy_send_timeout 7d;
        proxy_buffering off;
    }

    location /ssh {
        if (\$http_upgrade != "websocket") { return 444; }
        proxy_pass http://ssh_ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_read_timeout 7d;
        proxy_send_timeout 7d;
        proxy_buffering off;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location / {
        if (\$http_upgrade !~* "websocket") { return 444; }
        rewrite ^.*\$ / break;
        proxy_pass http://\$root_upstream;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$http_host;
        proxy_read_timeout 7d;
        proxy_send_timeout 7d;
        proxy_buffering off;
    }
}
NGX_EOF

systemctl daemon-reload
systemctl enable nginx --now >/dev/null 2>&1
nginx -t 2>&1 | grep -q "syntax is ok" && print_success "Nginx config valid." || print_error "Nginx config invalid!"
check_service nginx
print_success "Module 08-nginx complete."
