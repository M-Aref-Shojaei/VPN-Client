# Adaptive VPN Client — Knowledge Base

> **Product:** A cross-platform proxy client that sends known or learned blocked domains through a
> sing-box tunnel and leaves other traffic on the normal direct route.

---

## Current delivery state

The repository is migrating from captured v2rayN runtime files into a real product codebase.
Version `0.1.0` contains:

- A Flutter client targeting Android, iOS, Windows, macOS, and Linux.
- A tested Go adaptive-routing and configuration core.
- Direct-by-default routing with explicit, known-blocked, and network-specific learned rules.
- sing-box TUN and mixed-inbound configuration generation.
- Profile JSON import and a responsive routing/profile/connection UI.
- A tested Linux process adapter with sing-box checksum verification, private runtime files,
  startup validation, PID identity checks, and graceful shutdown.
- OS-backed secure profile/policy/subscription persistence.
- VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard, and SSH share-link import.
- Bounded HTTPS subscriptions and Ed25519-verified blocked-domain rule updates.
- A conservative direct/proxy probe that records only verified failure evidence.
- Automatic Linux direct-failure triggers that re-probe both paths, learn only after verified proxy
  success, and update a live sing-box rule-set without restarting the tunnel.
- A group-restricted Linux privileged service protocol and hardened systemd package.
- A per-user named-pipe Windows service, protected sing-box lifecycle, and transactional
  install/update/rollback package.

The Linux service reaches the operating-system privilege boundary, but this workstation lacks usable
`CAP_NET_ADMIN`, so the real TUN integration gate remains open. Windows code is cross-compiled but
still needs real-device TUN/DNS validation. Legacy credential migration, mobile/Apple adapters,
localization, and signed release artifacts remain roadmap work.

## Quick links

- [[00-Index/Project-Roadmap|Project Roadmap]]
- [[03-Product/Product-Requirements|Product Requirements]]
- [[01-Architecture/System-Overview|System Architecture Overview]]
- [[01-Architecture/Adaptive-Routing|Adaptive Routing Design]]
- [[01-Architecture/Profile-and-Config-Pipeline|Profile and Config Pipeline]]
- [[01-Architecture/Linux-Tunnel-Lifecycle|Linux Tunnel Lifecycle]]
- [[01-Architecture/Windows-Tunnel-Lifecycle|Windows Tunnel Lifecycle]]
- [[01-Architecture/Module-Catalog|Module Catalog]]
- [[01-Architecture/Secure-Storage-and-Imports|Secure Storage and Imports]]
- [[01-Architecture/Signed-Rule-Sets|Signed Rule Sets]]
- [[01-Architecture/Privileged-Control-Service|Privileged Control Service]]
- [[01-Architecture/Platform-Matrix|Platform Matrix]]
- [[01-Architecture/Hiddify-Reference-Baseline|Hiddify Reference Baseline]]
- [[05-Quality/Testing-Strategy|Testing Strategy]]
- [[06-Infrastructure/Development-Setup|Development Setup]]
- [[06-Infrastructure/Codex-Remote-Workflow|Codex Remote Workflow]]
- [[06-Infrastructure/System-Proxy-Integration|Legacy System Proxy Integration]]
- [[07-Decisions/ADR-Index|Architecture Decision Records]]
- [[08-Issues/Bug-Registry|Issue and Task Registry]]

## Repository map

| Path | Purpose | Status |
|---|---|---|
| `app/` | Flutter UI and platform projects | Active |
| `core/` | Go routing learner, policy engine, config generator, CLI | Active |
| `bin/` | Local sing-box/mihomo/Xray binaries | Runtime-only, ignored |
| `binConfigs/` | Legacy generated Xray/sing-box runtime configs and scripts | Reference |
| `guiConfigs/` | Legacy v2rayN UI configuration | Reference |
| `docs/Project-Knowledge-Base/` | Product and engineering documentation | Active |

## Terminology

- **Domain**, not URL: HTTPS normally hides the path, so routing decisions are made for hostnames
  such as `example.com`, not `/private/page`.
- **Direct-by-default:** an unmatched destination uses the device's ordinary connection.
- **Known blocked:** a maintained or user-provided domain rule uses the proxy immediately.
- **Learned blocked:** repeated direct failure plus successful proxy retry causes a temporary,
  network-specific proxy decision.
- **Network fingerprint:** a stable local identifier for the current ISP/network context; it must
  not contain raw credentials.

---

*Last updated: 2026-07-21*
