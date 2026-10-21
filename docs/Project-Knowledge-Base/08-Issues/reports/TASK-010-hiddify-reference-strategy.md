---
id: task-010-report
title: Hiddify Reference Strategy
created: 2026-07-21
tags: [report, architecture, hiddify, licensing]
---

# TASK-010 — Hiddify Reference Strategy

## Problem

The product owner identified Hiddify as the preferred application example and allowed either a fork
or an inspired independent client. The choice affects licensing, branding, release automation,
architecture, and how much of the current implementation remains useful.

## Solution

- Reviewed the current Hiddify App and Hiddify Core repositories at pinned commits.
- Confirmed that current Hiddify exposes desktop TUN in its UI and delegates privileged desktop TUN
  behavior to its Go core/service layer.
- Recorded the extended license constraints of a direct derivative.
- Selected a clean-room behavioral-reference approach that preserves the project's independent
  Flutter UI, hardened platform control boundary, and adaptive-routing engine.
- Split follow-up delivery into product design, desktop TUN, and live smart-routing tracks.

## Files changed

- `docs/Project-Knowledge-Base/01-Architecture/Hiddify-Reference-Baseline.md`
- `docs/Project-Knowledge-Base/07-Decisions/ADR-006-Hiddify-Reference-Strategy.md`
- `docs/Project-Knowledge-Base/07-Decisions/ADR-Index.md`
- `docs/Project-Knowledge-Base/00-Index/Home.md`
- `docs/Project-Knowledge-Base/00-Index/Project-Roadmap.md`
- `docs/Project-Knowledge-Base/01-Architecture/System-Overview.md`
- `docs/Project-Knowledge-Base/08-Issues/Bug-Registry.md`

## Verification

- The reviewed upstream commit IDs and package version are recorded for reproducibility.
- The roadmap continues to report Linux and Windows TUN as incomplete until real integration tests
  pass.
- No Hiddify source, asset, or generated file was added to the project.
