# 🔒 VPN Client — Knowledge Base

> **About the project:** A multi-protocol VPN/proxy client (v2rayN-style), built on top of the
> sing-box/mihomo/brook/hysteria backend binaries. Runs on Linux, integrates with GNOME and KDE
> system proxy settings. Currently mid-development: smart router just added, UI/UX redesign planned
> next (see [[07-Decisions/ADR-Index]] and reference-app research below).

---

## 🧭 Quick Links (Map of Content)

### 📌 Getting Started
- [[00-Index/Project-Roadmap|Project Roadmap]]

### 🏗️ Architecture & Standards
- [[01-Architecture/System-Overview|System Architecture Overview]]
- [[02-Governance/Coding-Standards|Coding Standards]]
- [[02-Governance/Push-Checklist|Push Checklist (pre-push gates)]]
- [[07-Decisions/ADR-Index|Architecture Decision Records (ADRs)]]

### 🐛 Issues & Tasks
- [[08-Issues/Bug-Registry|Bug Registry (Master Task List)]]

### 🚀 Infrastructure
- [[06-Infrastructure/System-Proxy-Integration|System Proxy Integration (GNOME/KDE)]]

---

## 🏗️ Project Structure

- **`bin/`** — backend protocol binaries: sing-box, mihomo, brook, hysteria/hysteria2, xray, v2fly,
  tuic, juicity, naiveproxy, mieru, overtls, shadowquic, srss, plus GeoIP/GeoSite databases. Gitignored.
- **`binConfigs/`** — generated backend config (`config.json`, `configPre.json`: DNS servers,
  routing/detour rules) and shell scripts for OS-level proxy integration and sudo-gated
  start/stop (`run_as_sudo.sh`, `kill_as_sudo.sh`, `proxy_set_linux_sh.sh`).
- **`guiConfigs/`** — GUI state/config (`guiNConfig.json`, `guiNDB.db`).
- **`guiLogs/`** — daily run logs.

**Tech Stack:** Bash (system integration scripts), JSON-based backend configs (sing-box format).
GNOME (`gsettings`) and KDE (`kwriteconfig5`/`kwriteconfig6` + D-Bus) both supported for system
proxy application.

**Reference apps for the planned redesign:** [hiddify-app](https://github.com/hiddify/hiddify-app)
(Flutter, same protocol coverage, only genuinely cross-platform open-source alternative to v2rayN —
see comparison research below) and Streisand (iOS, closed-source, UX reference only).

---

## 📁 Vault Directory Structure

| Folder | Purpose |
|--------|---------|
| `00-Index` | Home, Roadmap |
| `01-Architecture` | System overview: how routing/backend selection works |
| `02-Governance` | Coding standards, push checklist |
| `06-Infrastructure` | System proxy integration (GNOME/KDE), backend binary management |
| `07-Decisions` | Architecture Decision Records (ADRs) — incl. reference-app research |
| `08-Issues` | Bug Registry + closed-task reports |

---
*Last Updated: 2026-07-07*
