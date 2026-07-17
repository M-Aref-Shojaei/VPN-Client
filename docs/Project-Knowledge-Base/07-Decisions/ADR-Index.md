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
| | UI/UX redesign reference app (hiddify-app vs. Streisand) | 🔄 Research done, no decision yet | 2026-07 |

Reference-app research (hiddify-app is the strongest open-source reference: same protocol coverage,
only genuinely cross-platform Win/macOS/Linux/iOS/Android client) currently lives in the vault note
`Professional/VPN Client.md` — promote it to a real ADR here once the redesign direction (custom
build vs. adopting hiddify-app patterns/fork) is actually decided.

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
