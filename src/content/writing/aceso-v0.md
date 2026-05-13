---
title: 'Shipping Aceso V0'
description: 'Notes on Aceso V0 — a local-first AI ops agent that watches Prometheus and Loki and runs its diagnosis loop on a Raspberry Pi over WireGuard.'
pubDate: 2026-05-13
tags: ['agents', 'observability']
---

I just deployed V0 of [Aceso](https://github.com/emil-oestergaard/aceso),
a small AI ops agent I've been building. It watches a single Linux
server through its existing observability stack — Prometheus for alerts,
Loki for logs — and asks a local LLM what is going wrong. V0 is
read-only: it diagnoses incidents and writes them to disk. The path to
acting on the server runs through V1 and V2, with a human in the loop
before anything autonomous.

The shape is a Go service that polls Prometheus for firing alerts every
thirty seconds. For each alert it pulls a window of correlated log lines
from Loki, built deterministically from the alert's labels, and asks an
Ollama instance for two fields: `cause` and `suggested_action`. The
result is appended as a JSON line to `incidents.json`. `tail -F` plus
`jq` is a perfectly good live view; nothing in the agent insists on a
fancier surface.

The choice I'm most interested in is where the model runs. Aceso's
production topology is one Hetzner CX23 running the agent and a 16 GB
Raspberry Pi running Ollama, joined by a plain WireGuard tunnel. The
binary contains no code paths to third-party LLM APIs — it cannot call
out to a frontier provider even if I wanted it to. End-to-end
provisioning is two scripts: one runs on the Pi, brings up `wg0`,
pins an Ollama version, gates on a warm-generation benchmark, and
stamps itself ready; the other runs on the CX23, brings up the matching
tunnel, and runs a cross-tunnel smoke test that POSTs the exact prompt
shape Aceso uses to confirm the Pi answers with valid JSON before the
agent ever starts.

That topology is not the cheapest path to a working demo. The cheapest
path is an API key and an HTTP client. But the demo is not the product.
The product is something I can put in front of a small VPS without
sending its log lines to a third party, without paying per-token for an
incident loop that runs every thirty seconds, and without a dependency
chain that includes anyone else's outage. For ops tooling on servers I
actually run, those properties matter more than the marginal quality of
a frontier model. A Pi sitting on my desk is also a far easier object to
reason about than a vendor account: I can pull the power cable and see
exactly what fails.

One V0 design choice worth flagging: when the local model is
unreachable, the agent does not fabricate a diagnosis. It writes a
structured escalation line, pushes a notification, and persists the
incident with `escalated: true`. A silent agent during an incident
would imply that something was checked when nothing was, and that is
worse than no agent at all. The fact that the model could not be
reached becomes the alert.

V0 is intentionally read-only because I do not yet trust any LLM to
take remediation actions on a server. V1 is action proposals with a
human approving each one; V2 is bounded autonomous remediation for
specifically whitelisted runbooks. That ramp is the part I expect to
spend the most time on — the read-only loop was the easy half. The
real question V1 forces is whether a model can write an action proposal
that a human is willing to approve at 02:00 without thinking hard, and
that is the one I want to test next.

The repository, the ADRs, and the deployment runbook are in
[`emil-oestergaard/aceso`](https://github.com/emil-oestergaard/aceso).
