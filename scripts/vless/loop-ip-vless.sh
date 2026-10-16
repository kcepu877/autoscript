#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by vvip
# Description: Service entrypoint for VLESS IP-limit enforcement
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/vvip/autoscript
# ========================================================
exec /usr/local/sbin/limit-ip-vless
