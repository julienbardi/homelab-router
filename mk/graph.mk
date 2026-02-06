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
#   1) config.mk   — shared variables
#   2) router.mk   — router control plane
#   3) certs.mk    — certificate lifecycle
#   4) caddy.mk    — Caddy lifecycle
#   5) tools.mk    — local tooling
# ------------------------------------------------------------

include mk/config.mk
include mk/router.mk
include mk/certs.mk
include mk/caddy.mk
include mk/tools.mk

.PHONY: all-full
all-full: all caddy
