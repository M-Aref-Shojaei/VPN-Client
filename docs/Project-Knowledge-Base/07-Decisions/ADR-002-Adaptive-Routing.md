---
id: adr-002
title: ADR-002 — Direct-by-default adaptive routing
created: 2026-07-18
tags: [decisions, adr, routing, privacy]
---

# ADR-002: Direct-by-default adaptive routing

**Status:** ✅ Accepted  
**Date:** 2026-07-18  
**Deciders:** Aref

## Context

Static country splitting sends many reachable destinations through the proxy and cannot adapt to
ISP-specific blocking. Probing every destination adds latency, traffic, and privacy exposure. A
transport-level fallback can also be unsafe after application data has been forwarded.

## Options considered

1. Proxy everything except domestic geo rules.
2. Direct everything except a maintained block list.
3. Race direct and proxy for every connection.
4. Direct-first with known rules plus conservative, expiring learning.

## Decision

Use manual overrides and maintained rules for immediate decisions. Default unknown destinations to
direct. Learn a temporary proxy decision only from a strong direct failure followed by proxy
success before payload forwarding. Scope learning by network and expire it.

## Consequences

- Reachable traffic avoids proxy bandwidth and latency.
- Known blocked traffic has no discovery delay.
- The first unknown blocked connection can be slower.
- False positives are limited by confirmation, network isolation, and expiry.
- UDP/QUIC needs separate handling because generic replay is unsafe.
- The learned database is sensitive local browsing metadata.
