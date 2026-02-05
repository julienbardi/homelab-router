# homelab-router

Operator‑grade automation and configuration for an ASUS RT‑AX86U Pro router.  
This project turns the router into a reproducible, script‑driven control‑plane node: SSH preflight guards, DynDNS lifecycle, and Caddy deployment are all orchestrated through a Makefile instead of ad‑hoc GUI clicks.

## Goals

- Reproducible router setup with no tribal knowledge.
- Operator‑friendly workflows with explicit, honest output.
- Safe experimentation through scripted, reviewable changes.
- Clear separation between host‑side automation and router‑side scripts.

## Features

### SSH preflight guard
- Validates host, port, and connectivity before any action.
- Emits actionable diagnostics when connectivity is wrong or ambiguous.
- Encodes invariants so later Make targets can assume SSH is sane.

### DynDNS lifecycle
- Router‑side DynDNS update script and config template.
- Host‑side Make targets to deploy, update, and maintain DynDNS logic.
- Removes legacy ddns/deploy installer in favor of a unified lifecycle.

### Caddy deployment (WIP)
- Scripts to install and manage a Caddy binary on the router’s JFFS partition.
- Make targets for install, reload, and configuration validation.
- Designed to eventually front router services with clean HTTPS.

### Makefile orchestration
- High‑level targets for preflight, deploy, update, and diagnostics.
- Consistent operator output: no ambiguous “…” noise, only meaningful markers.
- Modular Makefile fragments under mk/ for help and graphing.

## Repository layout

- **Makefile** — entry point for all operator workflows.
- **jffs/scripts/** — router‑side scripts (Caddy lifecycle, DynDNS helpers).
- **caddy/** — Caddy configuration (Caddyfile).
- **mk/** — Makefile fragments (help.mk, graph.mk).
- **README.md** — this document.

## Usage

### 1. Clone the repo

```sh
git clone git#github.com:julienbardi/homelab-router.git
cd homelab-router
`

### 2. Validate SSH access

`sh
make ssh-check
`

Ensures connectivity and port configuration before any deployment.

### 3. Deploy DynDNS

Adjust the DynDNS config template, then:

```sh
make dyndns-deploy
`

Installs the DynDNS script and configuration onto the router.

### 4. Manage Caddy (experimental)

```sh
make caddy-install
make caddy-reload
`

Installs the Caddy binary and reloads configuration via router‑side scripts.

## Operator principles

- No hidden state: everything important is in Git or on JFFS.
- Explicit contracts: preflight checks encode assumptions.
- Honest output: written for operators, not demos.
- Small, composable steps: each Make target does one thing well.

## Status

This repo is actively evolving as the homelab architecture is refactored to remove single points of failure and make the router a reproducible component of the control plane. Breaking changes are possible but always intentional and documented.

## License

To be added. For now, treat this as personal homelab infrastructure; reuse ideas freely but expect rapid iteration.
