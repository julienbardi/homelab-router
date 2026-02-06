# mk/router.mk
# ------------------------------------------------------------
# ROUTER CONTROL PLANE
# ------------------------------------------------------------
#
# Responsibilities:
#   - SSH preflight and connectivity validation
#   - Privilege escalation guard (run-as-root)
#   - Router bootstrap and helper installation
#   - Firewall and dnsmasq convergence
#   - Router diagnostics and invariants
#
# Concurrency:
#   - All targets in this file mutate router state
#   - Targets listed in .NOTPARALLEL MUST NOT run concurrently
#
# Contracts:
#   - MUST NOT invoke $(MAKE)
#   - MUST be correct under 'make -j'
#   - MUST NOT rely on timestamps for remote state
# ------------------------------------------------------------
.NOTPARALLEL: \
	firewall-install \
	firewall-ensure \
	firewall-started \
	firewall \
	dnsmasq-cache \
	install-run-as-root \
	install-ddns \
	install-caddy \
	install-certs \
	require-run-as-root \
	ssh-check

define deploy_if_changed
	@LOCAL_SHA=$$(sha256sum $(1) | awk '{print $$1}'); \
	REMOTE_SHA=$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"sha256sum $(2) 2>/dev/null | awk '{print \$$1}'" || true); \
	if [ "$$LOCAL_SHA" != "$$REMOTE_SHA" ]; then \
		echo "🚀 Deploying $(notdir $(2))..."; \
		ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "mkdir -p $(dir $(2))"; \
		scp -q -O -P $(ROUTER_SSH_PORT) $(1) $(ROUTER_HOST):$(2); \
		ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "chmod 0755 $(2)"; \
		echo "✅ $(notdir $(2)) updated"; \
	else \
		echo "✨ $(notdir $(2)) already up-to-date"; \
	fi
endef

.PHONY: router-ready
router-ready: firewall-started dnsmasq-cache
	@echo "🛡️  Router base services converged"

.PHONY: router-prepare
router-prepare: router-ready require-run-as-root fix-acme-perms
	@$(run_as_root) $(CERTS_DEPLOY) prepare

.PHONY: fix-acme-perms
fix-acme-perms:
	@if [ -d "$(ACME_HOME)" ]; then \
		echo "[acme] fixing permissions"; \
		$(run_as_root) find "$(ACME_HOME)" -type f -name "*.key" -exec chmod 600 {} \; ; \
		$(run_as_root) find "$(ACME_HOME)" -type f ! -name "*.key" -exec chmod 644 {} \; ; \
		$(run_as_root) find "$(ACME_HOME)" -type d -exec chmod 700 {} \; ; \
		$(run_as_root) chown -R root:root "$(ACME_HOME)"; \
	fi

.PHONY: ssh-check
ssh-check:
	@command -v nc >/dev/null 2>&1 || \
	( \
		echo "❌ Missing dependency: nc (netcat)"; \
		echo "Install it with: sudo apt install netcat-openbsd"; \
		exit 1; \
	)
	@ssh -p $(ROUTER_SSH_PORT) -o BatchMode=yes -o ConnectTimeout=5 \
		$(ROUTER_HOST) true >/dev/null 2>&1 || \
	( \
		echo "❌ SSH preflight failed"; \
		exit 1; \
	)

.PHONY: require-run-as-root
require-run-as-root: | ssh-check
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		test -x "$(RUN_AS_ROOT)" || \
		( echo "❌ run-as-root missing"; exit 1 ) \
	'

.PHONY: install-run-as-root
install-run-as-root: | ssh-check
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/run-as-root.sh,\
		$(RUN_AS_ROOT))

.PHONY: install-ddns
install-ddns: | ssh-check
	$(call deploy_if_changed,\
		$(SRC_DDNS)/ddns-start,\
		$(ROUTER_SCRIPTS)/ddns-start)

.PHONY: dnsmasq-cache
dnsmasq-cache: | ssh-check
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		mkdir -p /jffs/configs && \
		touch $(DNSMASQ_CONF_ADD) && \
		if grep -qx "$(DNSMASQ_CACHE_LINE)" $(DNSMASQ_CONF_ADD); then \
			echo "dnsmasq cache OK"; \
		else \
			echo "$(DNSMASQ_CACHE_LINE)" > $(DNSMASQ_CONF_ADD); \
			service restart_dnsmasq; \
		fi \
	'

.PHONY: firewall-install
firewall-install: | ssh-check require-run-as-root
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/firewall-start,\
		/jffs/scripts/firewall-start)

.PHONY: firewall-ensure
firewall-ensure: firewall-install | ssh-check
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
		/jffs/scripts/firewall-start \
	'

.PHONY: firewall-started
firewall-started: firewall-ensure

.PHONY: firewall
firewall: firewall-ensure

.PHONY: bootstrap
bootstrap: install-run-as-root install-ddns dnsmasq-cache firewall-install
	@echo "✅ Bootstrap complete"

.PHONY: router-health
router-health: ssh-check
	@echo "🩺 Router health check"
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		set -e; \
		echo "→ System:"; \
			uname -a; \
		echo "→ Uptime:"; \
			uptime; \
		echo "→ Storage:"; \
			df -h /jffs /tmp/mnt/sda || true; \
		echo "→ Firewall:"; \
			if iptables -L INPUT -n | grep -qE "ACCEPT.*tcp.*dpt:443"; then \
				echo "   ✓ HTTPS ingress allowed"; \
			else \
				echo "   ❌ HTTPS ingress missing"; exit 1; \
			fi; \
		echo "→ WireGuard:"; \
			if iptables -L WGSI >/dev/null 2>&1; then \
				echo "   ✓ WGSI (WireGuard server ingress) present"; \
				iptables -L WGSI -n -v | sed "s/^/     /"; \
			else \
				echo "   ❌ WGSI chain missing"; exit 1; \
			fi; \
			if iptables -L WGCI >/dev/null 2>&1; then \
				echo "   ✓ WGCI (WireGuard client ingress) present"; \
				iptables -L WGCI -n -v | sed "s/^/     /"; \
			else \
				echo "   ❌ WGCI chain missing"; exit 1; \
			fi; \
		echo "→ Caddy:"; \
			test -x "$(CADDY_BIN)" || { echo "   ❌ binary missing"; exit 1; }; \
			pidof caddy >/dev/null || { echo "   ❌ process not running"; exit 1; }; \
			$(CADDY_BIN) validate --config $(CADDYFILE_DST) >/dev/null 2>&1 || \
				{ echo "   ❌ config invalid"; exit 1; }; \
			echo "   ✓ binary present"; \
			echo "   ✓ process running"; \
			echo "   ✓ config valid"; \
		echo "✅ Router healthy" \
	'
	
.PHONY: router-health-strict
router-health-strict: router-health | ssh-check
	@echo "🔒 Enforcing strict security invariants"
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		set -e; \
		echo "→ OpenVPN:"; \
			if pidof openvpn >/dev/null 2>&1; then \
				echo "   ❌ OpenVPN process running"; exit 1; \
			fi; \
			echo "   ✓ OpenVPN disabled"; \
		echo "→ PPTP:"; \
		if pidof pptpd >/dev/null 2>&1; then \
			echo "   ❌ PPTP daemon running"; exit 1; \
		fi; \
		echo "   ✓ PPTP disabled"; \
		echo "→ IPsec:"; \
		if pidof charon >/dev/null 2>&1 || pidof pluto >/dev/null 2>&1; then \
			echo "   ❌ IPsec daemon running"; exit 1; \
		fi; \
		echo "   ✓ IPsec disabled"; \
		echo "→ SSH access:"; \
		if iptables -L INPUT -n | grep -qE "ACCEPT.*tcp.*dpt:(22|2222).*0.0.0.0/0"; then \
			echo "   ❌ SSH exposed via firewall"; exit 1; \
		fi; \
		echo "   ✓ SSH not exposed via firewall"; \
		echo "→ Web UI:"; \
		if iptables -L INPUT -n | grep -qE "ACCEPT.*tcp.*dpt:(80|443).*0.0.0.0/0"; then \
			echo "   ❌ Web UI exposed on WAN"; exit 1; \
		fi; \
		echo "   ✓ Web UI not exposed on WAN"; \
		echo "→ SSH keys:"; \
		echo " ✓ SSH key authentication works"; \
		echo "✅ Strict security posture verified" \
	'
