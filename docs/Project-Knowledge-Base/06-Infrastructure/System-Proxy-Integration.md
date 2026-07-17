---
id: system-proxy-integration
title: System Proxy Integration
created: 2026-07-07
tags: [infrastructure, proxy, gnome, kde]
---

# System Proxy Integration

Home: [[00-Index/Home]]

`binConfigs/proxy_set_linux_sh.sh` detects the running desktop environment and applies/clears the
OS-level system proxy so other apps (browsers, etc.) route through the backend without per-app config:

- **GNOME** (and XFCE/Cinnamon/UKUI/DDE/MATE, treated the same): `gsettings set org.gnome.system.proxy.*`
- **KDE**: `kwriteconfig5`/`kwriteconfig6` (version picked via `$KDE_SESSION_VERSION`) writing to
  `kioslaverc`, then a D-Bus signal (`org.kde.KIO.Scheduler.reparseSlaveConfiguration`) to make KIO
  re-read it live. KDE also gets the GNOME settings applied first — needed for KDE apps built on
  GTK/GIO that read gsettings directly.
- Fallback: if `gsettings` is available but no known DE is detected (minimal WM setups), falls back
  to the GNOME path.

Usage: `proxy_set_linux_sh.sh <mode> [proxy_ip proxy_port ignore_hosts]`, `mode` = `manual` or `none`.

Backend process start/stop is sudo-gated via `run_as_sudo.sh` / `kill_as_sudo.sh` (not yet documented
in detail here — fill in once the smart router / backend-selection logic stabilizes).
