#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by kcepu877
# Description: Check active VLESS logins + quota usage
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/kcepu877/autoscript
# ========================================================
. /usr/local/sbin/lib/account.sh

db_init
xray_cek_monitor vless
ui_back
menu
