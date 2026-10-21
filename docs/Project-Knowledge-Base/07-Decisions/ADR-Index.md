---
id: adr-index
title: Architecture Decision Records — Index
created: 2026-07-07
tags: [decisions, adr, index, architecture]
---

# Architecture Decision Records (ADR Index)

An ADR records a significant architectural decision: the context, the options considered, the
choice made, and the consequences. Only write one when the decision is hard to reverse or
future-you will ask "why did we do it this way."

Related: [[01-Architecture/System-Overview]] | [[00-Index/Project-Roadmap]]

---

## ADR List

| # | Title | Status | Date |
|---|-------|--------|------|
| [[07-Decisions/ADR-001-Product-Foundation\|ADR-001]] | Flutter + Go/sing-box clean product foundation | ✅ Accepted | 2026-07-18 |
| [[07-Decisions/ADR-002-Adaptive-Routing\|ADR-002]] | Direct-by-default adaptive routing | ✅ Accepted | 2026-07-18 |
| [[07-Decisions/ADR-003-Linux-Control-Boundary\|ADR-003]] | Linux process and privilege boundary | ✅ Accepted | 2026-07-18 |
| [[07-Decisions/ADR-004-Privileged-Linux-Service\|ADR-004]] | Group-restricted privileged Linux service | ✅ Accepted | 2026-07-19 |
| [[07-Decisions/ADR-005-Secure-Updates\|ADR-005]] | Secure profiles and verified remote rules | ✅ Accepted | 2026-07-19 |
| [[07-Decisions/ADR-006-Hiddify-Reference-Strategy\|ADR-006]] | Hiddify reference without a source fork | ✅ Accepted | 2026-07-21 |
| [[07-Decisions/ADR-007-Windows-Service-Boundary\|ADR-007]] | Windows service and named-pipe boundary | ✅ Accepted | 2026-07-21 |

---

## ADR Template

```markdown
---
id: adr-00X
title: ADR-00X — <decision title>
created: <date>
tags: [decisions, adr, <relevant-tags>]
---

# ADR-00X: <decision title>

**Status:** 🔄 In Progress | ✅ Accepted | ❌ Rejected | 🗄️ Superseded
**Date:** <date>
**Deciders:** Aref

---

## Context
<What's the situation forcing this decision?>

## Options Considered
<What alternatives were weighed?>

## Decision
<What was chosen and why>

## Consequences
<What this makes easier/harder going forward>
```
