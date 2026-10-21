---
id: product-requirements
title: Product Requirements
created: 2026-07-18
tags: [product, requirements]
---

# Product Requirements

## User outcome

The user connects once. Sites reachable on the ordinary network stay direct; blocked sites use the
selected proxy without requiring a manual mode switch.

## Functional requirements

- Run on Android, iOS, Windows, macOS, and Linux.
- Import common proxy subscriptions and individual protocol links.
- Support at minimum VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard, and SSH through
  a sing-box-compatible core.
- Offer full-device TUN and local proxy modes where the platform permits.
- Provide manual direct/proxy domain overrides.
- Consume maintained blocked-domain rule sets.
- Learn temporary network-specific decisions from verified fallback results.
- Explain the route and reason for a domain.
- Recover safely across sleep, network changes, process death, and core crashes.

## Non-functional requirements

- Unknown destinations default direct in smart-routing mode.
- Route lookup adds no network request and remains effectively constant/logarithmic time.
- Learned-state and profile updates are atomic.
- No credential, subscription URL, or browsing history telemetry by default.
- Failure must not leave a system proxy, route, DNS setting, service, or driver in an inconsistent
  state.
- Core and rule-set updates are checksum/signature verified and rollback-capable.
- UI meets keyboard, screen-reader, contrast, and scalable-text requirements.

## Explicit non-goals for `0.1.0`

- Claiming that URL paths can be classified under HTTPS.
- Learning from HTTP response codes.
- Racing every direct and proxy connection.
- Supporting many interchangeable cores before the sing-box vertical slice is reliable.
- Shipping unsigned drivers or bypassing platform security requirements.

## Success measures

- Direct traffic does not traverse the proxy in packet-capture tests.
- Known blocked traffic succeeds through the proxy without first-visit delay.
- Unknown blocked traffic learns after the configured evidence threshold.
- A false learning entry expires and direct access automatically recovers.
- Network A learning does not affect Network B.
- DNS leak, IPv6, QUIC, captive portal, and network-switch suites pass per platform.
