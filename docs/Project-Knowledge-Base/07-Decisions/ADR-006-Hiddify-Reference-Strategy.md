---
id: adr-006
title: ADR-006 — Hiddify reference without a source fork
created: 2026-07-21
tags: [decisions, adr, architecture, hiddify, licensing]
---

# ADR-006: Hiddify reference without a source fork

**Status:** ✅ Accepted  
**Date:** 2026-07-21  
**Deciders:** Aref

## Context

The product owner selected Hiddify as the closest example and requested a changed design, reliable
Windows/Linux TUN mode, and the project's adaptive routing data. Hiddify now exposes desktop TUN
in its shared UI and implements privileged behavior in a separate Go core, so both the product and
service boundary are useful references.

Hiddify's extended GPL terms require applications using its code to be noncommercial public GitHub
forks, released through GitHub Actions, attributed, and visibly different in name and interface.
The existing project already has an independent Flutter client, hardened Linux boundary, secure
storage/import pipeline, and adaptive routing engine.

## Options considered

1. Replace the repository with a Hiddify fork.
2. Import Hiddify Core into the existing Flutter application.
3. Continue the independent implementation and study Hiddify behavior/architecture only.

## Decision

Continue the clean-room Flutter + Go/sing-box implementation. Use Hiddify as a behavioral and
architectural reference, with no source, assets, or generated bindings copied into the product.

Prioritize the requested work as distinct product design, Linux/Windows TUN vertical slices, and
live adaptive-routing integration. Preserve the stricter local privilege and IPC boundaries already
designed in this project.

## Consequences

- Existing tested work remains usable instead of being rewritten around another project's state
  model and RPC surface.
- Product identity and future licensing choices remain independent.
- Hiddify improvements are not inherited automatically and must be evaluated and implemented.
- Windows privileged service/driver work and real Linux TUN validation remain substantial release
  gates.
- Exact UI work remains blocked only on identifying which visual components the product owner wants
  changed; technical TUN and routing work can continue independently.
