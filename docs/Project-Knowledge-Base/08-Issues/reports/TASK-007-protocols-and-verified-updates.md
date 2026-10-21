---
id: task-007-report
title: Protocol Imports and Verified Updates
created: 2026-07-19
tags: [report, profiles, subscriptions, security]
---

# TASK-007 — Protocol Imports and Verified Updates

## Problem

The application accepted only a manual sing-box JSON envelope and had no bounded subscription or
authenticated blocked-domain update path.

## Solution

- Added VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, WireGuard, and SSH share-link parsing.
- Mapped WireGuard to the current sing-box endpoint schema and validated an example with the pinned
  sing-box 1.13.14 binary.
- Added HTTPS-only JSON/base64 subscriptions with redirect, status, byte, count, and schema bounds.
- Added same-origin rule manifests with increasing version, SHA-256, and Ed25519 verification.
- Added UI flows, secure metadata persistence, deduplication, deletion, refresh, and error
  redaction.

## Main files

- `app/lib/src/models/profile_link_parser.dart`
- `app/lib/src/models/subscription.dart`
- `app/lib/src/models/rule_set.dart`
- `app/lib/src/services/subscription_service.dart`
- `app/lib/src/services/rule_set_service.dart`
- `core/configbuilder/config.go`
- `core/wireguard-profile.example.json`

## Verification

- Protocol, secure snapshot, subscription, and signed-rule Flutter tests pass.
- Flutter analysis reports no issues.
- Go configuration tests pass.
- Both standard and WireGuard examples pass sing-box `check`.
