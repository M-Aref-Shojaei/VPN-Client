---
id: adr-007
title: ADR-007 — Windows service and named-pipe boundary
created: 2026-07-21
tags: [decisions, adr, windows, security]
---

# ADR-007: Windows service and named-pipe boundary

**Status:** ✅ Accepted
**Date:** 2026-07-21
**Deciders:** Aref

## Context

Smart TUN requires machine-level interface and route operations on Windows. Elevating the Flutter
application would expose its large UI and dependency surface to administrator privileges and make
credential handling harder to constrain.

## Options considered

1. Run the entire Flutter application as Administrator.
2. Prompt for elevation on every connection and launch a transient helper.
3. Install a small LocalSystem service and expose a restricted per-user named pipe.

## Decision

Use a small Go Windows service with fixed installed paths and a per-installing-user named-pipe ACL.
Flutter remains unprivileged. The protocol exposes only bounded lifecycle and probe operations;
profile JSON travels over standard input and the pipe, never in command arguments. Native binaries
are checksum-verified and installed into content-addressed version directories so update and
rollback can switch between immutable versions.

## Consequences

- The privileged attack surface is limited to `routerctl`, the named-pipe decoder, and sing-box.
- Installation and upgrades require one explicit Administrator action.
- A multi-user machine currently authorizes one installing user; adding users requires an explicit
  ACL-management feature.
- Code compilation can be verified off-device, but signed-driver, TUN, DNS, and route behavior
  remain Windows integration gates.
