---
title: 'Aceso'
description: 'A self-healing AI agent for a single Linux server. Polls Prometheus and Loki, asks a local LLM (Ollama on a Raspberry Pi, reached over WireGuard) for a diagnosis, and escalates to a human on model failure.'
year: 2026
role: 'Design & engineering'
repo: 'https://github.com/emil-oestergaard/aceso'
featured: true
order: 0
---

A small Go service that watches a single VPS through its existing
observability stack — Prometheus for alerts, Loki for logs — and asks
a local LLM what is going wrong. No cloud LLMs in the binary by design.
V0 observes and diagnoses; V1 will propose actions with human approval;
V2 will run bounded remediation for whitelisted runbooks.
