---
id: report-task-001
title: TASK-001 — Adaptive routing core
created: 2026-07-18
tags: [report, routing, go]
---

# TASK-001: Adaptive routing core

## Problem

The original configurations implemented static country/rule splitting and sent unmatched Xray
traffic through the first proxy outbound. There was no testable blocked-domain learner, explicit
direct default, decision explanation, or safe persistence.

## Solution

- Added a Go domain normalizer and boundary matcher.
- Added deterministic manual/private/learned/known/default precedence.
- Added a network-specific learner requiring strong direct-failure plus proxy-success evidence.
- Rejected invalid signals, unsuccessful proxy retries, and observations after payload forwarding.
- Added threshold, expiry, pruning, atomic `0600` persistence, and deterministic listing.
- Added sing-box route and full runtime configuration generation.
- Omitted empty domain rules to prevent accidental catch-all proxy routing.
- Declared the default DNS resolver explicitly for sing-box 1.12+.
- Added the `routerctl decide`, `learn`, `export`, and `build` commands.
- Validated generated configuration with sing-box 1.13.14.

## Files changed

- `core/router/*.go`
- `core/configbuilder/*.go`
- `core/cmd/routerctl/main.go`
- `core/policy.example.json`
- `core/profile.example.json`
- `docs/Project-Knowledge-Base/01-Architecture/Adaptive-Routing.md`
- `docs/Project-Knowledge-Base/01-Architecture/Profile-and-Config-Pipeline.md`
- `docs/Project-Knowledge-Base/05-Quality/Testing-Strategy.md`
- `docs/Project-Knowledge-Base/07-Decisions/ADR-002-Adaptive-Routing.md`

## Verification

- `go test ./...`
- `go vet ./...`
- Generated example piped to `sing-box check` using bundled sing-box 1.13.14
