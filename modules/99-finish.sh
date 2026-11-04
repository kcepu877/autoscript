#!/bin/bash
set -euo pipefail
. "$INSTALL_DIR/lib/colors.sh"
. "$INSTALL_DIR/lib/helpers.sh"

clear
echo ""
echo -e "\e[0;42;30m              INSTALLATION COMPLETE                         \e[0m"
echo ""
echo -e " Run 'menu' to open the management panel."
echo -e " Tip: configure Telegram (System -> Telegram Setup) for notifications."
echo ""

print_success "Module 99-finish complete."
cat >>/root/.bashrc <<'EOF'

# Auto-launch menu on first login
if [[ $- == *i* ]] && [[ -z "$AUTO_MENU_LAUNCHED" ]]; then
    export AUTO_MENU_LAUNCHED=1
    if [[ -x /usr/local/sbin/menu ]]; then
        /usr/local/sbin/menu
    fi
fi
EOF

# Sync filesystem & beri waktu 5 detik sebelum reboot
sync
sleep 5
reboot
