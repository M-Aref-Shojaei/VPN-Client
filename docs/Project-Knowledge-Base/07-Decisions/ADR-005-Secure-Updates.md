---
id: adr-005
title: Secure Profiles and Verified Updates
created: 2026-07-19
status: accepted
tags: [adr, security, updates]
---

# ADR-005 — Secure Profiles and Verified Updates

## Context

Proxy profiles and subscription URLs contain credentials. Remote domain rules directly control
traffic routing, so an unauthenticated or stale update could silently redirect destinations.

## Decision

- Persist profiles, policies, subscriptions, and trust metadata only through OS secure storage.
- Require HTTPS and bounded/schema-validated profile subscriptions.
- Require increasing version, same HTTPS origin, SHA-256, and Ed25519 verification before changing
  known-blocked rules.
- Keep the previous rule set on every verification failure.
- Never automatically read legacy runtime settings from the repository.

## Consequences

- Linux desktop packages require a Secret Service implementation.
- Users must establish the rule publisher's public key out of band.
- Subscription availability does not weaken signed-rule authenticity.
- Explicit legacy import/migration remains a separate, user-authorized action.
