---
id: bug-registry
title: Bug Registry
created: 2026-07-07
updated: 2026-07-21
tags: [issues, bugs, registry, tracking]
---

# Bug Registry

Home: [[00-Index/Home]]

Master list of all known bugs and delivery tasks. Every solved item links to a report describing
the actual implementation.

**Categories:** `functionality` · `integration` · `third-party` · `security` · `refactor` · `feature`

**Status:** 🔴 Open · 🟡 In Progress · ✅ Solved
**Severity:** P1 critical · P2 high · P3 medium · P4 low

| ID | Category | Description | Severity | Status | Project | Area | Report |
|:---|:---------|:-------------|:---------|:-------|:--------|:-----|:-------|
| TASK-004 | integration | Complete Linux privilege boundary and real TUN integration test | P2 | 🟡 In Progress | all | infrastructure | — |
| TASK-005 | integration | Implement Android, Apple, and Windows native tunnel adapters | P2 | 🔴 Open | all | infrastructure | — |
| TASK-006 | security | Complete explicit legacy credential migration; secure persistence/redaction are implemented | P2 | 🟡 In Progress | all | security | — |
| TASK-008 | integration | Complete signed release artifacts and rollback; CI/checksums are implemented | P2 | 🟡 In Progress | all | infrastructure | — |
| TASK-011 | feature | Deferred: redesign selected surfaces when the product owner resumes design work | P3 | 🔴 Open | gui | frontend | — |
| TASK-001 | feature | Document and test deterministic adaptive routing precedence | P3 | ✅ Solved | core | backend | [[08-Issues/reports/TASK-001-adaptive-routing-core]] |
| TASK-002 | feature | Create responsive cross-platform UI foundation based on product requirements | P3 | ✅ Solved | gui | frontend | [[08-Issues/reports/TASK-002-flutter-client-foundation]] |
| TASK-009 | security | Add Codex Cloud setup and repository upload safety preflight | P2 | ✅ Solved | all | infrastructure | [[08-Issues/reports/TASK-009-codex-cloud-safety]] |
| TASK-007 | feature | Add subscription/link parsers and verified remote rule-set updates | P3 | ✅ Solved | core | backend | [[08-Issues/reports/TASK-007-protocols-and-verified-updates]] |
| TASK-010 | refactor | Evaluate Hiddify as fork or reference and lock the product architecture boundary | P2 | ✅ Solved | all | architecture | [[08-Issues/reports/TASK-010-hiddify-reference-strategy]] |
| TASK-003 | feature | Feed automatic data-plane failures into the implemented direct/proxy observer | P2 | ✅ Solved | core | backend | [[08-Issues/reports/TASK-003-automatic-smart-routing]] |
| TASK-012 | security | Implement the Windows service, protected lifecycle, and rollback foundation | P2 | ✅ Solved | all | infrastructure | [[08-Issues/reports/TASK-012-windows-service-foundation]] |

## Rules

- New items go at the top of the open rows; solved rows stay at the bottom.
- Every solved row links `08-Issues/reports/<ID>-<short-name>.md`.
- IDs use `BUG-###` for defects and `TASK-###` for features/refactors; never reuse an ID.
- A platform is not marked solved until it creates and tears down a real tunnel in an integration
  test.
