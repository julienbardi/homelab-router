# Makefile for homelab router configuration
#
# dnsmasq-cache is declarative:
# - Always re-evaluates router state
# - Updates config only if semantics change
# - Uses a local stamp file as a restart signal
# - Restarts dnsmasq only when required
# - Consumes and clears the stamp after restart

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

ROUTER_HOST      := julie@10.89.12.1
ROUTER_SSH_PORT  := 2222
ROUTER_SCRIPTS   := /jffs/scripts
REPO_ROOT        := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ROUTER_USER      := $(word 1,$(subst @, ,$(ROUTER_HOST)))
ROUTER_ADDR      := $(word 2,$(subst @, ,$(ROUTER_HOST)))

DNSMASQ_CONF_ADD := /jffs/configs/dnsmasq.conf.add
DNS_CACHE_SIZE   := 10000
DNSMASQ_CACHE_LINE := cache-size=$(DNS_CACHE_SIZE)
DNSMASQ_CHANGED  := .dnsmasq-cache-changed

TOOLS_DIR        := .tools
CHECKMAKE        := $(TOOLS_DIR)/checkmake

# ------------------------------------------------------------
# Help / entry points
# ------------------------------------------------------------

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make install-ddns        Install DynDNS script to router"
	@echo "  make test-ddns           Run DynDNS script manually on router"
	@echo "  make dnsmasq-cache       Enable dnsmasq DNS cache and restart service"
	@echo "  make doctor              Validate router environment"
	@echo "  make all                 Install DDNS and configure dnsmasq (parallel)"
	@echo "  make clean               Remove local state files"

.PHONY: all
all: install-ddns dnsmasq-cache

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
	@ssh -p $(ROUTER_SSH_PORT) -o BatchMode=yes -o ConnectTimeout=5 \
		$(ROUTER_HOST) true >/dev/null 2>&1 || \
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
# DynDNS
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns: | ssh-check
	@echo "📡 Installing DynDNS script on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"mkdir -p $(ROUTER_SCRIPTS)"
	@scp -q -O -P $(ROUTER_SSH_PORT) \
		"$(REPO_ROOT)/ddns/ddns-start" \
		$(ROUTER_HOST):$(ROUTER_SCRIPTS)/ddns-start
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"chmod 755 $(ROUTER_SCRIPTS)/ddns-start"
	@echo "✨ DynDNS installation complete."

.PHONY: test-ddns
test-ddns: | ssh-check
	@echo "🧪 Running DynDNS script manually on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"/jffs/scripts/ddns-start"

# ------------------------------------------------------------
# Environment checks
# ------------------------------------------------------------

.PHONY: doctor
doctor: | ssh-check
	@echo "🩺 Running environment checks on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -d /jffs/scripts || echo '⚠️  Missing /jffs/scripts directory'"
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f /jffs/scripts/ddns-start || echo '⚠️  DynDNS script not installed'"
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f /jffs/scripts/.ddns_confidential || echo '⚠️  Missing secrets file'"
	@echo "✨ Doctor check complete."

# ------------------------------------------------------------
# dnsmasq cache management
# ------------------------------------------------------------

.PHONY: dnsmasq-show
dnsmasq-show: | ssh-check
	@echo "🔎 Inspecting dnsmasq cache configuration..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f $(DNSMASQ_CONF_ADD) && \
		 grep -E '^cache-size=' $(DNSMASQ_CONF_ADD) || \
		 echo 'ℹ️  No cache-size configured'"

.NOTPARALLEL: dnsmasq-restart
dnsmasq-restart: $(DNSMASQ_CHANGED) | ssh-check
	@echo "🔄 Restarting dnsmasq..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"service restart_dnsmasq"
	@rm -f $(DNSMASQ_CHANGED)
	@echo "✅ dnsmasq restarted"

.PHONY: dnsmasq-cache
dnsmasq-cache: $(DNSMASQ_CHANGED) dnsmasq-show

.PHONY: FORCE
FORCE:

$(DNSMASQ_CHANGED): FORCE | ssh-check
	@echo "🧠 Ensuring dnsmasq cache configuration..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		mkdir -p /jffs/configs && \
		touch $(DNSMASQ_CONF_ADD) && \
		if grep -qx "$(DNSMASQ_CACHE_LINE)" $(DNSMASQ_CONF_ADD); then \
			echo "ℹ️  dnsmasq cache already correct"; \
			exit 0; \
		else \
			echo "$(DNSMASQ_CACHE_LINE)" > $(DNSMASQ_CONF_ADD); \
			echo "🔁 dnsmasq cache updated"; \
			exit 42; \
		fi' ; \
	rc=$$?; \
	if [ $$rc -eq 42 ]; then \
		touch $@; \
	else \
		rm -f $@; \
	fi

# ------------------------------------------------------------
# Tooling
# ------------------------------------------------------------

.PHONY: clean
clean:
	@rm -f $(DNSMASQ_CHANGED)

.PHONY: lint
lint: tools
	@$(CHECKMAKE) Makefile || true

.PHONY: tools
tools: $(CHECKMAKE)

$(CHECKMAKE):
	@echo "🔧 Bootstrapping checkmake..."
	@mkdir -p $(TOOLS_DIR)
	@command -v go >/dev/null || \
		(echo "❌ Go is required to install checkmake: run sudo apt install golang-go"; exit 1)
	@GOBIN=$(abspath $(TOOLS_DIR)) \
		go install github.com/checkmake/checkmake/cmd/checkmake@latest
	@echo "✅ checkmake installed at $(CHECKMAKE)"
