ROUTER_HOST := julie@10.89.12.1
ROUTER_SCRIPTS := /jffs/scripts
REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make install-ddns     Install DynDNS script to router"
	@echo "  make test-ddns        Run DynDNS script manually on router"
	@echo "  make doctor           Validate router environment"

# ------------------------------------------------------------
# DynDNS installation
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns:
	@echo "📡 Installing DynDNS script on router..."
	ssh $(ROUTER_HOST) "mkdir -p $(ROUTER_SCRIPTS)"
	scp "$(REPO_ROOT)/ddns/ddns-start" $(ROUTER_HOST):$(ROUTER_SCRIPTS)/ddns-start
	ssh $(ROUTER_HOST) "chmod 755 $(ROUTER_SCRIPTS)/ddns-start"
	@echo "✨ DynDNS installation complete."

# ------------------------------------------------------------
# DynDNS test
# ------------------------------------------------------------

.PHONY: test-ddns
test-ddns:
	@echo "🧪 Running DynDNS script manually on router..."
	ssh $(ROUTER_HOST) "/jffs/scripts/ddns-start"

# ------------------------------------------------------------
# Basic environment checks
# ------------------------------------------------------------

.PHONY: doctor
doctor:
	@echo "🩺 Running environment checks on router..."
	ssh $(ROUTER_HOST) "test -d /jffs/scripts || echo '⚠️  Missing /jffs/scripts directory'"
	ssh $(ROUTER_HOST) "test -f /jffs/scripts/ddns-start || echo '⚠️  DynDNS script not installed'"
	ssh $(ROUTER_HOST) "test -f /jffs/scripts/.ddns_confidential || echo '⚠️  Missing secrets file'"
	@echo "✨ Doctor check complete."
