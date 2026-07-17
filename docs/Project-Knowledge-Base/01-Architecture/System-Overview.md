---
id: system-overview
title: System Architecture Overview
created: 2026-07-07
tags: [architecture]
---

# System Architecture Overview

Home: [[00-Index/Home]]

## Shape
1. **Backend layer** (`bin/`): a swappable set of proxy protocol implementations (sing-box, mihomo,
   brook, hysteria/hysteria2, xray, v2fly, tuic, juicity, naiveproxy, mieru, overtls, shadowquic,
   srss), selected/driven via generated JSON config (`binConfigs/config.json`, built from
   `binConfigs/configPre.json` — DNS servers, routing/detour rules, the "smart router").
2. **System integration layer** (`binConfigs/*.sh`): applies/removes the OS-level system proxy
   (GNOME via `gsettings`, KDE via `kwriteconfig5`/`6` + D-Bus signal to reparse), and
   starts/stops the backend process with sudo (`run_as_sudo.sh` / `kill_as_sudo.sh`).
3. **GUI layer** (`guiConfigs/`, `guiLogs/`): current GUI state/db and daily logs — the GUI itself
   (UI/UX) is the part planned for redesign, referencing hiddify-app.

## Open questions
- Exact routing rule format/precedence for the "smart router" — not yet documented here, fill in
  once the smart router design stabilizes.
- Whether the redesigned UI stays a custom build or migrates toward wrapping/forking hiddify-app
  (see [[07-Decisions/ADR-Index]] reference-app research — no decision made yet).
