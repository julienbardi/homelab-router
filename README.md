# homelab-router

Operator‑grade automation and configuration for an ASUS RT‑AX86U Pro router, extended into a small but explicit control plane for homelab networking.

This repository turns the router into a reproducible, script‑driven execution node. All intent is declared, all assumptions are encoded, and all changes are reviewable. GUI clicks are replaced by Make targets, shell scripts, and documented contracts.

The router is not treated as a snowflake. It is a component.

---

# Goals

- Reproducible router and VPN setup with no tribal knowledge
- Explicit separation between intent, logic, and execution
- Operator‑friendly workflows with honest, actionable output
- Safe experimentation through scripted, reviewable changes
- Ability to benchmark and evolve without impacting production traffic

---

# Architectural Overview

This repository participates in a three‑plane architecture:

- Control plane — declarative intent and topology
- Execution plane — scripts and devices that realize intent
- Data plane — actual routed and encrypted traffic

The router and NAS are execution nodes. Intent lives outside them.

---

# Control Plane

The control plane defines *what should exist*.

It consists of:

- domain.yaml (private, authoritative)
- domain.example.yaml (synthetic, documented schema)
- Documentation under docs/

The domain model declares:

- Servers (router, NAS) and their stable management IPs
- WireGuard interfaces and where they run
- Reachable LAN and VPN subnets
- Access profiles (split tunnel, full tunnel)
- Valid profile‑to‑interface bindings

The domain model intentionally does not encode:

- Client operating systems
- WireGuard AllowedIPs
- Routing tables
- Firewall or NAT behavior
- Benchmarking logic

Those are derived later.

---

# Execution Plane

The execution plane realizes intent.

It consists of:

- The ASUS RT‑AX86U Pro router
- The NAS (hosting additional WireGuard servers for benchmarking)
- Shell scripts under jffs/scripts/
- Makefile orchestration and helpers under mk/

Responsibilities include:

- SSH preflight validation
- DynDNS lifecycle management
- WireGuard configuration compilation
- Deployment and reload of router‑side services
- Optional benchmarking interfaces on the NAS

Execution logic may evolve without changing the domain model.

---

# Data Plane

The data plane carries traffic:

- WireGuard tunnels
- Encrypted packets
- Routed LAN and Internet flows

All data‑plane behavior is derived from execution‑plane output.

---

# Features

## SSH preflight guard

- Validates host, port, and connectivity before any action
- Emits actionable diagnostics when connectivity is wrong or ambiguous
- Encodes invariants so later Make targets can assume SSH is sane

## DynDNS lifecycle

- Router‑side DynDNS update script and config template
- Host‑side Make targets to deploy, update, and maintain DynDNS logic
- Unified lifecycle replacing legacy ad‑hoc installers

## WireGuard control plane

- Declarative domain model describing servers, interfaces, and policy
- Router hosts production WireGuard interfaces
- NAS hosts multiple WireGuard servers (wg1…wg15) for benchmarking
- AllowedIPs, routes, and OS‑specific behavior are derived by scripts

## Caddy deployment (WIP)

- Scripts to install and manage a Caddy binary on the router’s JFFS partition
- Make targets for install, reload, and configuration validation
- Intended to front router services with clean HTTPS

## Makefile orchestration

- High‑level targets for preflight, deploy, update, and diagnostics
- Consistent operator output: no ambiguous noise, only meaningful markers
- Modular Makefile fragments under mk/ for help and graphing

---

# Repository Layout

- Makefile — entry point for all operator workflows
- domain.example.yaml — documented domain schema (synthetic data)
- docs/ — architecture, domain model, and derivation rules
- jffs/scripts/ — router‑side scripts (DynDNS, WireGuard helpers, Caddy)
- caddy/ — Caddy configuration
- mk/ — Makefile fragments (help, graphing, structure)
- README.md — this document

---

# Documentation

Conceptual documentation lives under docs/:

- domain-model.md — what belongs in the domain model and why
- allowedips-derivation.md — how routing intent becomes AllowedIPs
- architecture.md — control plane vs execution plane vs data plane
- benchmarking.md — rationale and isolation of performance testing

These documents explain boundaries and intent. They do not duplicate shell logic.

---

# Usage

## Clone the repository

`git clone git@github.com:julienbardi/homelab-router.git
cd homelab-router`

## Validate SSH access

`make ssh-check`

Ensures connectivity and port configuration before any deployment.

## Deploy DynDNS

Adjust the DynDNS config template, then:

`make dyndns-deploy`

Installs the DynDNS script and configuration onto the router.

## Manage Caddy (experimental)

`make caddy-install
make caddy-reload`

Installs the Caddy binary and reloads configuration via router‑side scripts.

---

# Operator Principles

- No hidden state: everything important is in Git or on JFFS
- Explicit contracts: preflight checks encode assumptions
- Honest output: written for operators, not demos
- Small, composable steps: each Make target does one thing well
- Intent first, mechanics second

---

# Status

This repository is actively evolving as the homelab architecture is refactored to:

- Remove single points of failure
- Make the router a reproducible execution node
- Support controlled benchmarking and experimentation
- Preserve long‑term auditability

Breaking changes are possible, but always intentional and documented.

---

# License

To be added.

For now, treat this as personal homelab infrastructure. Reuse ideas freely, but expect rapid iteration and opinionated design.
