---
id: profile-config-pipeline
title: Profile and Configuration Pipeline
created: 2026-07-18
tags: [architecture, configuration, profiles]
---

# Profile and Configuration Pipeline

## Canonical profile envelope

```json
{
  "id": "profile-id",
  "name": "Display name",
  "outbound": {
    "type": "vless",
    "server": "example.invalid",
    "server_port": 443
  }
}
```

The outbound is intentionally opaque to the UI and uses sing-box's outbound schema. The core
requires a non-empty type and rejects routing/meta outbounds (`direct`, `block`, `dns`, `selector`,
and `urltest`) as a user proxy.

The UI also accepts the eight share-link families documented in
[[01-Architecture/Secure-Storage-and-Imports]]. WireGuard is placed in top-level `endpoints` for
sing-box 1.13; all other supported profiles are placed in `outbounds`.

## Pipeline

```text
subscription/link/manual JSON
        ↓ parse and validate
canonical profile envelope
        ↓ load active route policy and learned state
configbuilder.Build
        ↓
complete sing-box JSON
        ↓ sing-box check
platform-private runtime file
        ↓
native adapter starts the packaged core
```

## Generated defaults

- TUN inbound: dual-stack address, `auto_route`, `strict_route`, system stack.
- Mixed inbound: loopback-only port `2080`.
- DNS: local resolver for bootstrap and proxied DoH for general queries.
- Outbounds: active profile tagged `proxy`, plus `direct`.
- Routing: DNS hijack, adaptive rules, explicit direct final route.

The TUN and mixed inbound flags are configurable. At least one must be enabled.

## Credential handling

Version `0.1.0` persists the versioned profile/policy document through platform secure storage.
There is no plaintext fallback. Runtime files are owner-only, profile data travels to Linux control
over standard input/socket payloads rather than arguments, and UI errors redact storage/network
exceptions. Legacy repository settings are never imported automatically.

Subscription URLs may contain bearer query parameters and are treated as credentials. Diagnostics
contain only safe error categories, never profile, URL, UUID, password, or key values.
