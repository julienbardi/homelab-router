# mk/graph.mk
# mk/graph.mk
# ------------------------------------------------------------
# ENTRYPOINT — GLOBAL DEPENDENCY GRAPH
# ------------------------------------------------------------
#
# Purpose:
#   - Assemble all modules into a single dependency graph
#   - Define inclusion order and global structure
#
# Inclusion order is significant:
#   1) config.mk     — shared variables (no targets, no recipes)
#   2) platform.mk   — shell ABI bootstrap (deploy-common)
#   3) router.mk     — router control plane
#   4) wireguard.mk  — WireGuard lifecycle
#   5) certs.mk      — certificate lifecycle
#   6) caddy.mk      — Caddy lifecycle
#   7) tools.mk      — local tooling
# ------------------------------------------------------------

include mk/config.mk
include mk/platform.mk
include mk/router.mk
include mk/wireguard.mk
include mk/certs.mk
include mk/caddy.mk
include mk/tools.mk

.PHONY: all-full
all-full: all caddy
