---
id: signed-rule-sets
title: Signed Rule Sets
created: 2026-07-19
updated: 2026-07-19
tags: [architecture, security, routing]
---

# Signed Rule Sets

Home: [[00-Index/Home]]

## Trust format

The user configures an HTTPS manifest URL and a base64 Ed25519 public key. The manifest is limited
to 64 KiB:

```json
{
  "version": 2,
  "data_url": "/rules-v2.json",
  "sha256": "<64 lowercase hexadecimal characters>",
  "signature": "<base64 Ed25519 signature over the exact data bytes>"
}
```

The data URL must remain on the manifest's HTTPS origin. The payload is limited to 4 MiB and
100,000 normalized domains:

```json
{"domains":["blocked.example","video.example"]}
```

## Acceptance order

1. Validate HTTPS URL and response bounds.
2. Require an integer version newer than the installed version.
3. Resolve the data URL and enforce identical HTTPS origin.
4. Verify SHA-256 over exact response bytes.
5. Verify Ed25519 over the same bytes.
6. Validate and normalize every domain.
7. Replace `knownBlocked` and persist trusted metadata.

Any failure occurs before replacement, leaving the previous rule set active. Tests generate an
ephemeral Ed25519 key and cover valid, stale, cross-origin, and invalid-signature manifests.
