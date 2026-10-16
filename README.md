# Autoscript VPN

> Version: **5.4.0**

AutoScript VPN for **multi-OS** (Ubuntu 20/22, Debian 12, Rocky Linux 9).

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
