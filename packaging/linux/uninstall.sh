#!/usr/bin/env bash

set -euo pipefail

if ((EUID != 0)); then
  echo "Run this uninstaller explicitly as root." >&2
  exit 1
fi

systemctl disable --now adaptive-vpn.service 2>/dev/null || true
rm -f /etc/systemd/system/adaptive-vpn.service
rm -f /usr/lib/adaptive-vpn/routerctl /usr/lib/adaptive-vpn/sing-box
rmdir /usr/lib/adaptive-vpn 2>/dev/null || true
systemctl daemon-reload

echo "Adaptive VPN executables and service were removed."
echo "Private state in /var/lib/adaptive-vpn was preserved for explicit cleanup."
