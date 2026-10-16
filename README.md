# Autoscript VPN

> Version: **5.4.0** (Release) — see [CHANGELOG.md](CHANGELOG.md).

AutoScript VPN & Tunneling Management System, engineered for **multi-OS** (Ubuntu 20/22, Debian 12, Rocky Linux 9).

Enterprise-grade multi-protocol tunneling solution supporting SSH, SlowDNS (DNSTT), NoobzVPN, VLESS, VMESS, Trojan, and OpenVPN TCP with full WebSocket (WS), HTTPUpgrade (HU), XHTTP, and gRPC transport matrix, fronted by HAProxy and Nginx with dynamic auto-tuning and a unified Go RESTful API daemon.

---

## Features

- **SSH Stack**: OpenSSH + Dropbear (109) with SSH-over-WebSocket (GO-TUNNEL PRO) & BadVPN UDPGW (7300).
- **SlowDNS (DNSTT)**: High-security DNS Tunneling Server on ports 53/udp and 5300/udp.
- **NoobzVPN Core**: Native integration with authentic hardware device-id tracking.
- **Full Xray Transport Matrix**: VLESS, VMESS, Trojan over WebSocket, HTTPUpgrade, XHTTP, gRPC.
- **OpenVPN TCP**: Single consolidated service (1194) with auto-generated certificates.
- **HAProxy + Nginx Front**: Single-port TLS (443) and HTTP (80) multiplexing.
- **Go RESTful API Daemon**: High-performance FastHTTP daemon with token auth.
- **SQLite Single Source of Truth**: /etc/xray/xray.db (WAL mode).
- **Quota & IP / Device Limit**: Strict bandwidth quota and concurrent connection limiter.
- **Dynamic Auto-Tuning**: Automatically sizes Nginx, HAProxy, TCP buffers based on RAM/CPU.
- **SkyNode-Style Terminal UI**: Clean, adaptive ASCII interface.

---

## Supported Operating Systems

| OS | Version | Status |
|---|---|---|
| Ubuntu | 20.04 LTS | ✅ Tested |
| Ubuntu | 22.04 LTS | ✅ Supported |
| Debian | 12 (Bookworm) | ✅ Supported |
| Rocky Linux | 9 | ✅ Supported |

---

## Auto-Tuning Engine

| RAM Tier | Nginx Conn | HAProxy Maxconn | TCP Buffers | Swap | Swappiness |
|---|---|---|---|---|---|
| ≤ 1 GB | 4,096 | 8,192 | 16 MB | 2 GB | 60 |
| ≤ 2 GB | 16,384 | 32,768 | 32 MB | 2 GB | 15 |
| ≤ 4 GB | 65,535 | 100,000 | 64 MB | 4 GB | 15 |
| > 4 GB | 131,072 | 200,000 | 128 MB | 4 GB | 15 |

---

## Port Specifications

| Service | Port / Protocol | Description |
|---|---|---|
| OpenSSH | 22, 3303 / TCP | VPS Remote Administration |
| Dropbear | 109 / TCP | Primary SSH Service |
| HTTP Web | 80 / TCP | HAProxy → Nginx |
| HTTPS / TLS | 443 / TCP | Multi-Protocol TLS multiplexer |
| SlowDNS | 53, 5300 / UDP | DNS Stealth Tunneling |
| NoobzVPN | 8585 / TCP | NoobzVPN TCP |
| BadVPN / UDPGW | 7300 / UDP | UDP Forwarding |
| OpenVPN | 1194 / TCP | OpenVPN TCP tunnel |

### Internal Ports (127.0.0.1)

- Xray API: 10085
- Nginx Local: 81, 82
- SSH WebSocket Proxy: 8888
- SSH WebSocket API: 8081
- NoobzVPN Daemon: 8585
- Go RESTful API Daemon: 9000

---

## Installation (Ubuntu 20)

### 1. Install Screen

```bash
apt update && apt upgrade -y
apt install -y screen curl wget git
mkdir -p /run/screen && chmod 777 /run/screen
```

### 2. Clone Repo

```bash
git clone https://github.com/kcepu877/autoscript.git
cd autoscript
```

### 3. Install Script

```bash
screen -S autoscript
bash install.sh
```

### 4. Install API

```bash
bash install-api.sh
```

### 5. Selesai

```bash
menu
```

## Installation (Ubuntu 22)

```bash
apt update && apt upgrade -y
apt install -y screen curl wget git
git clone https://github.com/kcepu877/autoscript.git
cd autoscript
screen -S autoscript
bash install.sh
```

## Installation (Debian 12)

```bash
apt update && apt upgrade -y
apt install -y screen curl wget git
git clone https://github.com/kcepu877/autoscript.git
cd autoscript
screen -S autoscript
bash install.sh
```

## Installation (Rocky Linux 9)

```bash
dnf install -y epel-release
dnf install -y screen curl wget git
git clone https://github.com/kcepu877/autoscript.git
cd autoscript
screen -S autoscript
bash install.sh
```

## Uninstall

```bash
uninstall-api
uninstall
```

## Menu

```bash
menu
```

## License

Apache License 2.0
