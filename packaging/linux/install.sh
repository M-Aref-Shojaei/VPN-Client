#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"
routerctl="${project_root}/core/routerctl"
core="${project_root}/bin/sing_box/sing-box"
target_user=""

while (($#)); do
  case "$1" in
    --routerctl)
      routerctl="$2"
      shift 2
      ;;
    --core)
      core="$2"
      shift 2
      ;;
    --user)
      target_user="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if ((EUID != 0)); then
  echo "Run this installer explicitly as root, for example: sudo $0 --user \"\$USER\"" >&2
  exit 1
fi

if [[ ! -x "${routerctl}" || ! -x "${core}" ]]; then
  echo "routerctl and sing-box executable paths are required." >&2
  exit 1
fi

expected="68aeab83cc4ab2659a5b92232261a20746ccdafc3b3d1e19b2d63247eec3bbf7"
actual="$(sha256sum "${core}" | awk '{print $1}')"
if [[ "${actual}" != "${expected}" ]]; then
  echo "sing-box checksum verification failed." >&2
  exit 1
fi

if ! getent group adaptive-vpn >/dev/null; then
  groupadd --system adaptive-vpn
fi

install -d -o root -g root -m 0755 /usr/lib/adaptive-vpn
install -o root -g root -m 0755 "${routerctl}" /usr/lib/adaptive-vpn/routerctl
install -o root -g root -m 0755 "${core}" /usr/lib/adaptive-vpn/sing-box
install -o root -g root -m 0644 \
  "${script_dir}/adaptive-vpn.service" \
  /etc/systemd/system/adaptive-vpn.service

if [[ -n "${target_user}" ]]; then
  if ! id "${target_user}" >/dev/null 2>&1; then
    echo "Requested user does not exist: ${target_user}" >&2
    exit 1
  fi
  usermod -aG adaptive-vpn "${target_user}"
fi

systemctl daemon-reload
systemctl enable --now adaptive-vpn.service

echo "Adaptive VPN service installed."
if [[ -n "${target_user}" ]]; then
  echo "${target_user} must sign out and back in before using the control socket."
fi
