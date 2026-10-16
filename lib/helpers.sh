#!/bin/bash
# Helper Functions
AS_VERSION="${AS_VERSION:-5.4.0}"

print_header() {
  clear
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}           ENTERPRISE VPN AUTOSCRIPT INSTALLER              ${NC}"
  echo -e "${PURPLE}                    version ${AS_VERSION}                     ${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_service() {
  local svc="$1"
  local fatal="${2:-}"
  if systemctl is-active --quiet "$svc"; then
    print_success "Service '$svc' is active."
    return 0
  fi
  print_error "Service '$svc' failed to start."
  systemctl status "$svc" --no-pager -l 2>/dev/null | head -n 15
  if [[ "$fatal" == "fatal" ]]; then
    print_error "Critical service '$svc' is not running. Aborting."
    exit 1
  fi
  return 1
}

show_progress() {
  local duration=$1
  local col
  col=$(tput cols 2>/dev/null || echo 80)
  local width=$((col - 20))
  [[ $width -lt 20 ]] && width=20
  echo -ne "  Progress: ["
  for ((i = 0; i < width; i++)); do echo -ne " "; done
  echo -ne "] 0%"
  for ((i = 0; i <= width; i++)); do
    local per=$((i * 100 / width))
    echo -ne "\r  Progress: ["
    for ((j = 0; j < i; j++)); do echo -ne "■"; done
    for ((j = i; j < width; j++)); do echo -ne " "; done
    echo -ne "] $per%"
    sleep "$duration"
  done
  echo -e "\n"
}

detect_resources() {
  CPU_CORES=$(nproc 2>/dev/null)
  [[ "$CPU_CORES" =~ ^[0-9]+$ ]] || CPU_CORES=1
  RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
  [[ "$RAM_MB" =~ ^[0-9]+$ ]] || RAM_MB=1024

  if ((RAM_MB <= 1280)); then
    TIER="1GB"; NGX_CONN=4096; HA_MAXCONN=8192
    NET_BUF=16777216; XRAY_NOFILE=262144
  elif ((RAM_MB <= 2560)); then
    TIER="2GB"; NGX_CONN=16384; HA_MAXCONN=32768
    NET_BUF=33554432; XRAY_NOFILE=524288
  elif ((RAM_MB <= 5120)); then
    TIER="4GB"; NGX_CONN=65535; HA_MAXCONN=100000
    NET_BUF=67108864; XRAY_NOFILE=1000000
  else
    TIER="8GB+"; NGX_CONN=131072; HA_MAXCONN=200000
    NET_BUF=134217728; XRAY_NOFILE=1000000
  fi

  NGX_WORKERS=$CPU_CORES
  NGX_RLIMIT=$((NGX_CONN + 1024))
  FILE_MAX=$(((NGX_CONN * CPU_CORES) + 100000))
  ((FILE_MAX < 262144)) && FILE_MAX=262144
  TCP_RMEM_MAX=$NET_BUF
  TCP_WMEM_MAX=$NET_BUF

  export CPU_CORES RAM_MB TIER NGX_CONN HA_MAXCONN NET_BUF XRAY_NOFILE
  export NGX_WORKERS NGX_RLIMIT FILE_MAX TCP_RMEM_MAX TCP_WMEM_MAX
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VER="$VERSION_ID"
  else
    OS_ID="unknown"; OS_VER="unknown"
  fi

  case "$OS_ID" in
    ubuntu|debian)
      OS_FAMILY="debian"
      PKG_MGR="apt"
      PKG_INSTALL="apt install -y"
      PKG_UPDATE="apt update -y"
      PKG_REMOVE="apt remove -y"
      PKG_GROUP_BUILD="build-essential"
      FIREWALL="ufw"
      AUTH_LOG="/var/log/auth.log"
      NGINX_USER="www-data"
      OVPN_PLUGIN_DIR="/usr/lib/x86_64-linux-gnu/openvpn/plugins"
      OVPN_SVC_NAME="openvpn@server"
      EASYRSA_SRC="/usr/share/easy-rsa"
      ;;
    rocky|almalinux|centos|rhel|fedora)
      OS_FAMILY="rhel"
      PKG_MGR="dnf"
      PKG_INSTALL="dnf install -y"
      PKG_UPDATE="dnf makecache"
      PKG_REMOVE="dnf remove -y"
      PKG_GROUP_BUILD="@Development Tools"
      FIREWALL="firewalld"
      AUTH_LOG="/var/log/secure"
      NGINX_USER="nginx"
      OVPN_PLUGIN_DIR="/usr/lib64/openvpn/plugins"
      OVPN_SVC_NAME="openvpn-server@server-tcp-1194"
      EASYRSA_SRC="/usr/share/easy-rsa/3"
      ;;
    *)
      echo "Unsupported OS: $OS_ID $OS_VER" >&2
      exit 1
      ;;
  esac

  export OS_ID OS_VER OS_FAMILY PKG_MGR PKG_INSTALL PKG_UPDATE PKG_REMOVE
  export PKG_GROUP_BUILD FIREWALL AUTH_LOG NGINX_USER
  export OVPN_PLUGIN_DIR OVPN_SVC_NAME EASYRSA_SRC
}
