---
id: hiddify-reference-baseline
title: Hiddify Reference Baseline
created: 2026-07-21
updated: 2026-07-21
tags: [architecture, reference, hiddify, tun, routing]
---

# Hiddify Reference Baseline

Home: [[00-Index/Home]]

## Why it is a reference

Hiddify demonstrates a mature Flutter client structure across Android, iOS, Windows, macOS, and
Linux. Its useful product patterns include a compact connection surface, profile/subscription
management, responsive navigation, tray behavior, and a Flutter-to-Go core boundary.

The project remains a clean-room implementation. No Hiddify source is copied or linked. Its
extended GPL terms require published derivatives to be noncommercial GitHub forks, use GitHub
Actions for releases, attribute Hiddify, and avoid a similar name or interface. A direct fork would
therefore constrain product identity, distribution, and commercial options.

## Upstream snapshot reviewed

- Hiddify App main commit `276a7effb0046a039220a745022563740968c0b8`.
- Hiddify Core `v3` commit `1dd899bc60546d1aec94432ca0fb0e85801267fe`.
- App package version `4.1.2+40102` with Flutter `3.38.5`.
- Review date: 2026-07-21.

The repository advertises TUN support and its current UI includes desktop TUN as a service mode.
Android uses `VpnService`. Desktop privilege handling resides primarily in the separate Go core:
it checks Administrator or `CAP_NET_ADMIN`, installs/starts a platform service, and controls a
secondary TUN instance over a local RPC endpoint.

## Patterns accepted for this project

- Shared Flutter product layer with small platform-specific adapters.
- An unprivileged desktop UI controlling a privileged, independently supervised tunnel service.
- sing-box as the packet data plane.
- Explicit connection modes and a fast route/profile control surface.
- Platform lifecycle handling separated from profile and UI state.

## Patterns intentionally changed

- IPC must be authenticated by operating-system identity and locally scoped. Linux uses a
  group-restricted Unix socket; Windows will use an ACL-protected named pipe or equivalent service
  control boundary. A fixed unauthenticated loopback TCP port is not the target design.
- Smart routing is direct-by-default and combines signed known-blocked rules, user overrides, and
  temporary network-scoped learning. Static region rule modes alone do not satisfy the product.
- Failed direct requests are not blindly replayed. Learning accepts only pre-payload strong failure
  evidence followed by a successful proxy probe.
- The application has a distinct name, visual system, information architecture, and release
  identity.

## Resulting implementation tracks

1. **Product design:** compact connection/profile/mode controls plus an explainable routing
   activity surface, with exact visual changes driven by product-owner references.
2. **Desktop TUN:** finish the hardened Linux service vertical slice, then implement the Windows
   service and signed-driver lifecycle.
3. **Smart routing:** inject learned events from the live data plane, rebuild/reload routes safely,
   and prove direct/proxy behavior with DNS, IPv4, IPv6, TCP, and UDP integration tests.

## Source boundary

When a Hiddify idea affects implementation, documentation records the behavioral pattern and our
independent design. Developers must not paste Hiddify code, assets, translations, generated
bindings, or UI layouts into this repository.
