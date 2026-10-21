---
id: adr-001
title: ADR-001 — Product foundation
created: 2026-07-18
tags: [decisions, adr, architecture, flutter, go]
---

# ADR-001: Product foundation

**Status:** ✅ Accepted  
**Date:** 2026-07-18  
**Deciders:** Aref

## Context

The repository contained runtime output from v2rayN, not source for a distributable client. v2rayN
does not supply a mobile architecture. Hiddify supplies all five platforms, but its extended license
requires a public noncommercial Hiddify fork and imposes release, naming, and interface conditions.
The intended product needs its own routing behavior and may need independent branding/commercial
options.

## Options considered

1. Continue editing v2rayN runtime configuration.
2. Fork v2rayN.
3. Fork Hiddify.
4. Build a clean Flutter client with a Go/sing-box core.
5. Build separate native clients for every platform.

## Decision

Build a clean Flutter application for shared product/UI code and a Go control/routing core that
generates sing-box configuration. Implement privileged tunnel lifecycle through small native
platform adapters.

Use Hiddify and v2rayN for behavioral and architectural study only; do not copy their source.

## Consequences

- One UI codebase covers all five requested platforms.
- Packet-path performance remains in the Go/sing-box layer rather than Dart.
- The project owns its product identity and feature design.
- Native VPN work, secure storage, signing, and packaging still require platform expertise.
- sing-box licensing and distribution obligations require review before public/commercial release.
