---
id: adr-004
title: Privileged Linux Service
created: 2026-07-19
status: accepted
tags: [adr, linux, security]
---

# ADR-004 — Privileged Linux Service

## Context

Linux TUN and route management require privilege. Granting file capabilities to a general sing-box
binary would let every allowed user run arbitrary privileged configurations. Launching sudo from
the app would introduce password handling and an unsafe interactive boundary.

## Decision

Install a root systemd service with fixed executable/state paths and only
`CAP_NET_ADMIN`/`CAP_NET_RAW`. Authorize clients through a mode `0660`,
`root:adaptive-vpn` Unix socket. Accept only a bounded lifecycle protocol and canonicalize every
client-controlled probe option before invoking the fixed local command.

## Consequences

- The app never receives privilege or a password.
- Users cannot override privileged binary/config/state paths.
- Installation and group membership are explicit administrative actions.
- Linux packaging must keep the systemd sandbox and exact core checksum synchronized.
- A capable host is still required for the real TUN integration gate.
