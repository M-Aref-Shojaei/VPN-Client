---
id: coding-standards
title: Coding Standards
created: 2026-07-07
tags: [governance, standards]
---

# Coding Standards

Home: [[00-Index/Home]]

- Shell scripts (`binConfigs/*.sh`): `set -e` where practical, quote all variable expansions,
  functions for anything reused across desktop environments (see existing `detect_desktop_environment`
  pattern in `proxy_set_linux_sh.sh`).
- Backend config (`binConfigs/config.json`, `configPre.json`): keep `configPre.json` as the
  human-edited source of routing/DNS rules; treat `config.json` as generated output — don't hand-edit
  the generated file.
- No secrets (server credentials, subscription URLs) committed in `binConfigs/` — these are runtime
  configs and should be gitignored alongside `bin/`, `guiConfigs/guiNDB.db`, and `guiLogs/`.
