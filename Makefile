# Makefile
# Canonical entrypoint wrapper
# This file exists ONLY to forward to the real graph.

.DEFAULT_GOAL := help

MAKEFILE_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

include $(MAKEFILE_DIR)mk/graph.mk
include $(MAKEFILE_DIR)mk/help.mk

.PHONY: all
all: install-ddns dnsmasq-cache firewall-started

.PHONY: all-full
all-full: all caddy
	@echo "✅ Router and Caddy fully converged"

.PHONY: clean
clean:
	@rm -f $(DNSMASQ_CHANGED) $(SENTINEL_FW_INST) $(SENTINEL_FW_START)
	@echo "🧹 Local state cleaned"

.PHONY: test
test: test-preinstall