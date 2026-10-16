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
