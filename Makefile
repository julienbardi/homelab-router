# Defines user-facing targets and includes the real dependency graph.

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
	@echo "🧹 Local state cleaned"

.PHONY: test
test: test-preinstall