# homelab-router

Declarative, Git‑managed configuration for my Asus RT‑AX86U running Asuswrt‑Merlin.
This repository defines the router’s control‑plane: DynDNS updates, Caddy reverse
proxy, dnsmasq caching, WireGuard peer definitions, and startup scripts. Secrets
and runtime state stay on the router; only logic and policy live here.
