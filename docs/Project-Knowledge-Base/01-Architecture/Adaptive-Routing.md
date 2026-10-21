---
id: adaptive-routing
title: Adaptive Routing
created: 2026-07-18
updated: 2026-07-21
tags: [architecture, routing, privacy]
---

# Adaptive Routing

Related: [[01-Architecture/System-Overview]] | [[07-Decisions/ADR-002-Adaptive-Routing]]

## Decision precedence

The first matching decision wins:

1. Manual direct override
2. Manual proxy override
3. Private IP, loopback, link-local address, `localhost`, or `.local`
4. Active learned-blocked entry for the current network
5. Known-blocked rule
6. Default direct

Manual direct deliberately outranks manual proxy. It is the emergency escape hatch for banking,
government, captive-portal, and LAN destinations.

## Domain semantics

Inputs are trimmed, lower-cased, stripped of URL path/port/trailing dot, then matched on DNS label
boundaries. A rule for `example.com` includes `api.example.com`, but not `notexample.com`.

Full URL paths cannot normally be inspected under HTTPS. ECH, direct-IP clients, cached DNS, and
QUIC can also reduce hostname visibility. The product promises domain-level classification only.

## Learning evidence

An observation is accepted only when:

- the domain is valid;
- the direct attempt produced DNS poisoning, TCP reset, connection timeout, or TLS interference;
- the proxy retry succeeded; and
- no application payload had already been forwarded.

Two accepted observations mark a domain blocked for 24 hours by default. Entries are keyed by
`network fingerprint + domain`. Failed proxy retries, HTTP errors, and post-payload failures do not
teach the router.

## Persistence

Learned state is a JSON array in the application-data directory:

- parent directory: `0700`;
- file: `0600`;
- update: write temporary file, `fsync`, close, atomic rename;
- expiry: prune inactive/expired entries.

The state is local browsing metadata and must not be uploaded or included in diagnostics by default.

On Linux, `networkscope` hashes the selected default-route interface, gateway, and interface
hardware address and retains only a 64-bit hexadecimal prefix with a platform label. Raw network
identifiers are never written to learned state.

## Generated sing-box policy

- DNS traffic is hijacked to the configured DNS module.
- Manual direct domains route to `direct`.
- Private destination IPs route to `direct`.
- Manual, known, and active learned blocked domains route to `proxy`.
- The loopback-only mixed observer inbound always routes to `proxy`, so proxy verification cannot
  accidentally repeat the direct attempt.
- Active learned domains are also published through a private local source rule-set. sing-box
  automatically reloads the file after an atomic replacement, avoiding a tunnel restart.
- `route.final` is `direct`.
- `route.auto_detect_interface` prevents TUN routing loops.
- `route.default_domain_resolver` is explicit for sing-box 1.12+ compatibility.

An empty domain group is omitted. In sing-box, a route rule with no match fields is a catch-all, so
serializing an empty group would be a critical privacy/performance bug.

## Automatic Linux observer

The privileged service watches only newly appended sing-box error lines. A candidate must identify
a domain connection that failed specifically through `outbound/direct[direct]`. IP-only targets,
other outbounds, malformed domains, and invalid ports are ignored. Candidates are rate-limited and
then independently tested by the payload-free observer:

1. retry the direct TCP/TLS establishment with a bounded deadline;
2. classify only strong DNS, reset, timeout, or narrow TLS interference signals;
3. retry through the mixed inbound, which is forced to the real proxy outbound;
4. record evidence only when the proxy succeeds and no application payload was forwarded;
5. atomically refresh the active network's local sing-box rule-set after the evidence threshold.

This is learn-for-the-next-attempt behavior. The original failed application stream is not replayed,
which avoids duplicating non-idempotent requests. UDP/QUIC cannot use the same generic validation;
known rules route UDP immediately, while unknown QUIC still requires protocol-specific handling or
application fallback to TCP.
