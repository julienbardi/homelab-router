ROUTER_HOST := julie@10.89.12.1
ROUTER_SSH_PORT := 2222
ROUTER_SCRIPTS := /jffs/scripts
REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ROUTER_USER := $(word 1,$(subst @, ,$(ROUTER_HOST)))
ROUTER_ADDR := $(word 2,$(subst @, ,$(ROUTER_HOST)))

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make install-ddns     Install DynDNS script to router"
	@echo "  make test-ddns        Run DynDNS script manually on router"
	@echo "  make doctor           Validate router environment"

# ------------------------------------------------------------
# SSH preflight
# ------------------------------------------------------------

.PHONY: ssh-check
ssh-check:
	@command -v nc >/dev/null 2>&1 || \
	( \
		echo "❌ Missing dependency: nc (netcat)"; \
		echo ""; \
		echo "Install it with:"; \
		echo "  sudo apt install netcat-openbsd"; \
		echo ""; \
		exit 1; \
	)
	@echo "🔐 Checking SSH connectivity to router..."
	@ssh -p $(ROUTER_SSH_PORT) -o BatchMode=yes -o ConnectTimeout=5 $(ROUTER_HOST) true >/dev/null 2>&1 || \
	( \
		echo "❌ SSH preflight failed."; \
		echo ""; \
		echo "Diagnosis:"; \
		if ! nc -z -w5 $(ROUTER_ADDR) $(ROUTER_SSH_PORT) 2>/dev/null; then \
			echo "  • SSH port $(ROUTER_SSH_PORT) is not reachable"; \
			echo ""; \
			echo "Hints:"; \
			echo "  • Enable SSH on the router"; \
			echo "  • Verify SSH port $(ROUTER_SSH_PORT)"; \
			echo "  • Check firewall rules"; \
		else \
			echo "  • SSH is reachable, but key-based authentication failed"; \
			echo ""; \
			echo "Hints:"; \
			echo "  • Run: ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST)"; \
			echo "  • If prompted for a password, install your SSH key:"; \
			echo "      ssh-copy-id -p $(ROUTER_SSH_PORT) $(ROUTER_HOST)"; \
		fi; \
		echo ""; \
		exit 1; \
	)
	@echo "✅ SSH connectivity and authentication OK"

# ------------------------------------------------------------
# DynDNS installation
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns: ssh-check
	@echo "📡 Installing DynDNS script on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "mkdir -p $(ROUTER_SCRIPTS)"
	@scp -q -O -P $(ROUTER_SSH_PORT) "$(REPO_ROOT)/ddns/ddns-start" \
		$(ROUTER_HOST):$(ROUTER_SCRIPTS)/ddns-start
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"chmod 755 $(ROUTER_SCRIPTS)/ddns-start"
	@echo "✨ DynDNS installation complete."

# ------------------------------------------------------------
# DynDNS test
# ------------------------------------------------------------

.PHONY: test-ddns
test-ddns: ssh-check
	@echo "🧪 Running DynDNS script manually on router..."
	ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "/jffs/scripts/ddns-start"

# ------------------------------------------------------------
# Basic environment checks
# ------------------------------------------------------------

.PHONY: doctor
doctor: ssh-check
	@echo "🩺 Running environment checks on router..."
	ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -d /jffs/scripts || echo '⚠️  Missing /jffs/scripts directory'"
	ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f /jffs/scripts/ddns-start || echo '⚠️  DynDNS script not installed'"
	ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f /jffs/scripts/.ddns_confidential || echo '⚠️  Missing secrets file'"
	@echo "✨ Doctor check complete."
