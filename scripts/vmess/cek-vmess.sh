#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by vvip
# Description: Check active VMESS logins + quota usage
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/vvip/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
xray_cek_monitor vmess
ui_back
menu
