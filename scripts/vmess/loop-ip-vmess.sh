#!/usr/bin/env bash
# ========================================================
# Project: Autoscript VPN by kcepu877
# Description: Service entrypoint for VMESS IP-limit enforcement
# License: Apache License 2.0 (see LICENSE file)
# Repository: https://github.com/kcepu877/autoscript
# ========================================================
exec /usr/local/sbin/limit-ip-vmess
