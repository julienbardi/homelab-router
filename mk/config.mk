# mk/config.mk
# ------------------------------------------------------------
# GLOBAL CONFIGURATION
# ------------------------------------------------------------
#
# Purpose:
#   - Define all shared configuration variables
#   - Provide a single source of truth for paths, hosts, ports
#
# Contract:
#   - This file MUST NOT define targets or recipes
#   - This file MUST NOT perform side effects
#   - Variables defined here are read-only by convention
#
# Inclusion:
#   - MUST be included before any other module
# ------------------------------------------------------------

ROUTER_HOST      := julie@10.89.12.1
ROUTER_SSH_PORT  := 2222
ROUTER_SCRIPTS   := /jffs/scripts
REPO_ROOT        := $(MAKEFILE_DIR)

ROUTER_USER      := $(word 1,$(subst @, ,$(ROUTER_HOST)))
ROUTER_ADDR      := $(word 2,$(subst @, ,$(ROUTER_HOST)))

SRC_DDNS         := $(REPO_ROOT)ddns
SRC_CADDY        := $(REPO_ROOT)caddy
SRC_SCRIPTS      := jffs/scripts

DNSMASQ_CONF_ADD := /jffs/configs/dnsmasq.conf.add
DNS_CACHE_SIZE   := 10000
DNSMASQ_CACHE_LINE := cache-size=$(DNS_CACHE_SIZE)

CADDYFILE_SRC := $(SRC_CADDY)/Caddyfile
CADDYFILE_DST := /etc/caddy/Caddyfile
CADDY_BIN     := /tmp/mnt/sda/router/bin/caddy

TOOLS_DIR     := .tools
CHECKMAKE     := $(TOOLS_DIR)/checkmake

RUN_AS_ROOT := /jffs/scripts/run-as-root.sh
run_as_root := ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) $(RUN_AS_ROOT)
