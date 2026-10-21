---
id: secure-storage-and-imports
title: Secure Storage and Imports
created: 2026-07-19
updated: 2026-07-19
tags: [architecture, security, profiles, subscriptions]
---

# Secure Storage and Imports

Home: [[00-Index/Home]]

## Secure state

`SecureProfileStore` uses `flutter_secure_storage` 10.3.1. That maps to Android encrypted storage,
Apple Keychain, Linux secret service, and the package's Windows secure implementation. A single
versioned document stores:

- validated profile envelopes;
- active profile identifier;
- manual and known-blocked policy;
- HTTPS subscription URL, membership, and last update;
- trusted signed-rule manifest URL, Ed25519 public key, version, and verification time.

The encoded document is limited to 1 MiB, 500 profiles, 100 subscriptions, and 10,000 routing
entries. Load failures are redacted in UI diagnostics; raw storage/plugin exceptions are not shown.
Tests use `MemoryProfileStore`, which revalidates every save through the same schema.

The application does not automatically read the legacy repository runtime files. Users can import
an explicit share link or profile JSON, which avoids changing or silently copying existing VPN
settings.

## Share-link parsing

`ProfileLinkParser` accepts:

| Scheme | sing-box shape |
|---|---|
| `vless://` | VLESS outbound with TLS/Reality and WS/gRPC/HTTP Upgrade |
| `vmess://` | Base64 VMess JSON outbound |
| `trojan://` | Trojan outbound with TLS |
| `ss://`, `shadowsocks://` | Shadowsocks outbound; plugin links rejected |
| `hysteria2://`, `hy2://` | Hysteria2 outbound with TLS/obfuscation |
| `tuic://` | TUIC outbound with TLS |
| `wireguard://`, `wg://` | WireGuard endpoint for sing-box 1.13+ |
| `ssh://` | SSH outbound |

Links are limited to 64 KiB. Required server, port, keys/credentials, transport, Reality, MTU, and
WireGuard address fields are validated before persistence. Stable identifiers exclude credential
material.

## Subscriptions

`SubscriptionService` requires HTTPS without URL user-info. Redirects must remain HTTPS, bodies are
limited to 2 MiB, lists to 500 profiles, and both JSON envelopes and base64/plain link lists are
supported. Invalid updates do not replace the current subscription.

Subscription URLs may contain bearer query parameters, so they are stored in the secure document
and must never be printed in diagnostics.
