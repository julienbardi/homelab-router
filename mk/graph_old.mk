# mk/graph.mk
# Makefile for homelab router configuration
#
# dnsmasq-cache is declarative:
# - Always re-evaluates router state
# - Updates config only if semantics change
# - Uses a local stamp file as a restart signal
# - Restarts dnsmasq only when required
# - Consumes and clears the stamp after restart

# ------------------------------------------------------------
# MAKEFILE CONTRACT
# ------------------------------------------------------------
#
#   - This Makefile MUST NOT use recursive make.
#   - No recipe may invoke $(MAKE) or 'make'.
#   - All ordering and orchestration MUST be expressed
#     using Make dependencies (including order-only deps).
#
# Rationale:
#   - Preserve a single, global dependency graph
#   - Ensure correctness under 'make -j'
#   - Avoid hidden control flow in shell recipes
#
# Any change violating this contract is a BUG.
# ------------------------------------------------------------

# ------------------------------------------------------------
# RUNTIME CAPABILITIES CONTRACT (ROUTER)
# ------------------------------------------------------------
#
# This Makefile targets an embedded Asus router environment
# (AsusWRT / AsusWRT-Merlin class).
#
# GUARANTEED AT RUNTIME
# --------------------
#   - BusyBox shell (/bin/sh)
#   - OpenSSL (for key/cert inspection and crypto primitives)
#   - Basic POSIX tools (cp, mv, chmod, grep, find, etc.)
#   - Writable /jffs filesystem
#   - SSH access as root (via run-as-root helper)
#
# NOT GUARANTEED / NOT ASSUMED
# ---------------------------
#   - NO package manager
#   - NO certbot
#   - NO lego
#   - NO acme.sh
#   - NO ACME client of any kind
#
# CONSEQUENCE
# -----------
#   - This Makefile MUST NOT assume the presence of any
#     certificate issuance binary or ACME implementation.
#   - Certificate issuance is treated as an EXTERNAL concern
#     unless explicitly provisioned and guarded.
#
# Any change that assumes additional runtime tooling
# without installing and guarding it is INVALID.
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

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

ROUTER_HOST      := julie@10.89.12.1
ROUTER_SSH_PORT  := 2222
ROUTER_SCRIPTS   := /jffs/scripts
REPO_ROOT        := $(MAKEFILE_DIR)

ROUTER_USER      := $(word 1,$(subst @, ,$(ROUTER_HOST)))
ROUTER_ADDR      := $(word 2,$(subst @, ,$(ROUTER_HOST)))

# Source Paths (Explicit)
SRC_DDNS         := $(REPO_ROOT)ddns
SRC_CADDY        := $(REPO_ROOT)caddy
SRC_SCRIPTS      := jffs/scripts

DNSMASQ_CONF_ADD := /jffs/configs/dnsmasq.conf.add
DNS_CACHE_SIZE   := 10000
DNSMASQ_CACHE_LINE := cache-size=$(DNS_CACHE_SIZE)

CADDY_SHA256  := 7d11d11dc1bc68b1e38ded9d7d9370ad96f0dd2721139f8b145305c6d8dc3897

CADDYFILE_SRC := $(SRC_CADDY)/Caddyfile
CADDYFILE_DST := /etc/caddy/Caddyfile
# Caddy binary (external disk)
CADDY_BIN := /tmp/mnt/sda/router/bin/caddy

TOOLS_DIR        := .tools
CHECKMAKE        := $(TOOLS_DIR)/checkmake

# Privilege execution helper (router: always root)
RUN_AS_ROOT := /jffs/scripts/run-as-root.sh
run_as_root := ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) $(RUN_AS_ROOT)

# Installed helpers
CERTS_CREATE := /jffs/scripts/certs-create.sh
CERTS_DEPLOY := /jffs/scripts/certs-deploy.sh
GEN_CLIENT_CERT    := /jffs/scripts/generate-client-cert.sh
GEN_CLIENT_WRAPPER := /jffs/scripts/gen-client-cert-wrapper.sh

.PHONY: install-caddy-reload
install-caddy-reload:
	@echo "🔍 Checking Caddy reload script on router..."
	@LOCAL_SHA=$$(sha256sum $(SRC_SCRIPTS)/caddy-reload.sh | awk '{print $$1}'); \
	REMOTE_SHA=$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"sha256sum /jffs/scripts/caddy-reload.sh 2>/dev/null | awk '{print \$$1}' || echo none"); \
	if [ "$$LOCAL_SHA" != "$$REMOTE_SHA" ]; then \
		echo "🔁 Installing updated Caddy reload script..."; \
		scp -O -P $(ROUTER_SSH_PORT) $(SRC_SCRIPTS)/caddy-reload.sh \
			$(ROUTER_HOST):/jffs/scripts/caddy-reload.sh; \
		ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
			"chmod 755 /jffs/scripts/caddy-reload.sh"; \
		echo "✅ Reload script updated"; \
	else \
		echo "✨ Reload script already up-to-date"; \
	fi

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
	@echo "✅ SSH connectivity and authentication validated successfully"

.PHONY: install-run-as-root
install-run-as-root: | ssh-check
	@echo "🔐 Ensuring run-as-root helper on router..."
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/run-as-root.sh,\
		$(RUN_AS_ROOT))


# ------------------------------------------------------------
# DynDNS
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns: | ssh-check
	@echo "📡 Ensuring DynDNS script on router..."
	$(call deploy_if_changed,\
		$(SRC_DDNS)/ddns-start,\
		$(ROUTER_SCRIPTS)/ddns-start)

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

.PHONY: capabilities
capabilities: | ssh-check
	@echo "🧭 Capabilities inventory (router)"
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		echo "Architecture  : $$(uname -m)"; \
		echo "Uptime        : $$(uptime || echo n/a)"; \
		echo "JFFS writable : $$(test -w /jffs && echo yes || echo no)"; \
		echo "Ext disk      : $$(test -d /tmp/mnt/sda && echo present || echo missing)"; \
		echo "Processes     : nas=$$([ -n "$$(pidof nas 2>/dev/null)" ] && echo up || echo down) caddy=$$([ -n "$$(pidof caddy 2>/dev/null)" ] && echo up || echo down)"; \
		for t in sh ash bash curl wget openssl grep sed awk tar sha256sum iptables; do \
			printf "%-13s : " $$t; \
			if command -v $$t >/dev/null 2>&1; then \
				echo present; \
			elif /bin/busybox --list 2>/dev/null | grep -qx $$t; then \
				echo "present (busybox)"; \
			else \
				echo missing; \
			fi; \
		done; \
		echo "Ports (80/443): $$(netstat -lnt 2>/dev/null | awk '"'"'{print $$4}'"'"' | egrep -q ":(80|443)$$" && echo bound || echo free)"; \
		echo "DNS resolve   : $$(nslookup example.com >/dev/null 2>&1 && echo ok || echo fail)"; \
		echo "HTTP outbound : $$(curl -sS -m 5 -o /dev/null -w '"'"'%{http_code}'"'"' http://example.com 2>/dev/null || echo err)"; \
	'

# ------------------------------------------------------------
# dnsmasq cache management (non-recursive; deterministic order)
# ------------------------------------------------------------

.PHONY: dnsmasq-show
dnsmasq-show: dnsmasq-ensure-config | ssh-check
	@echo "🔎 Inspecting dnsmasq cache configuration..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"test -f $(DNSMASQ_CONF_ADD) && \
		 grep -E '^cache-size=' $(DNSMASQ_CONF_ADD) || \
		 echo 'ℹ️  No cache-size configured'"

.PHONY: dnsmasq-cache
dnsmasq-cache: | ssh-check
	@echo "🧠 Ensuring dnsmasq cache configuration..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		mkdir -p /jffs/configs && \
		touch $(DNSMASQ_CONF_ADD) && \
		if grep -qx "$(DNSMASQ_CACHE_LINE)" $(DNSMASQ_CONF_ADD); then \
			echo "ℹ️  dnsmasq cache already correct"; \
		else \
			echo "$(DNSMASQ_CACHE_LINE)" > $(DNSMASQ_CONF_ADD); \
			echo "🔁 dnsmasq cache updated — restarting dnsmasq"; \
			service restart_dnsmasq; \
			echo "✅ dnsmasq restarted"; \
		fi \
	'


# ------------------------------------------------------------
# Tooling
# ------------------------------------------------------------

# NOTE:
# checkmake's maxbodylength rule is intentionally ignored.
# This Makefile favors explicit, readable operator recipes
# over minimal line count. Long recipes are a feature here.
.PHONY: lint
lint: tools
	@echo "ℹ️ checkmake enforces style rules; warnings are expected"
	@$(CHECKMAKE) --config .tools/checkmake.ini Makefile || true

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

# ------------------------------------------------------------
# Certificates
# ------------------------------------------------------------

.PHONY: certs-create
certs-create: require-run-as-root
	@$(run_as_root) $(CERTS_CREATE)

.PHONY: certs-deploy
certs-deploy: require-run-as-root certs-create
	@$(run_as_root) $(CERTS_DEPLOY)
	@echo "🔐 Certificates deployed"

.PHONY: certs-ensure
certs-ensure: certs-deploy
	@echo "🔁 certificates ensured"

.PHONY: certs-status
certs-status:
	@echo "CA private:"; \
		$(run_as_root) ls -l /jffs/ssl/private/ca/homelab_bardi_CA.key || true
	@echo "CA public:"; \
		$(run_as_root) ls -l /jffs/ssl/certs/homelab_bardi_CA.pem || true
	@echo "CA canonical:"; \
		$(run_as_root) ls -l /jffs/ssl/canonical/ca.cer || true
	@echo "Client certs:"; \
		$(run_as_root) ls -l /jffs/ssl/caddy/clients || true

.PHONY: certs-expiry
certs-expiry:
	@$(run_as_root) openssl x509 \
		-in /etc/ssl/certs/homelab_bardi_CA.pem \
		-noout -subject -enddate

.PHONY: certs-rotate-dangerous
certs-rotate-dangerous:
	@echo "🔥 CA ROTATION — this invalidates ALL client certs"
	@read -p "Type YES to continue: " r && [ "$$r" = "YES" ]
	@$(run_as_root) $(CERTS_CREATE) --force
	@$(run_as_root) $(CERTS_DEPLOY)

.PHONY: gen-client-cert
gen-client-cert: require-run-as-root
	@if [ -z "$(CN)" ]; then \
		echo "usage: make gen-client-cert CN=<name> [FORCE=1]"; exit 1; \
	fi
	@FORCE_FLAG=""; [ "$(FORCE)" = "1" ] && FORCE_FLAG="--force"; \
	ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"$(GEN_CLIENT_WRAPPER) '$(CN)' '$(RUN_AS_ROOT)' '/jffs/scripts' $$FORCE_FLAG"

# Neutral, explicit guard – will fail with a clear message until configured
.PHONY: issuer-available
issuer-available:
	@echo "❌ No certificate issuer is configured or available."
	@echo "   Next steps:"
	@echo "   1) Run: make capabilities"
	@echo "   2) Choose a strategy:"
	@echo "      • Degraded local TLS: use Caddy 'tls internal' OR self-signed via OpenSSL"
	@echo "      • Public issuance: provision an issuer (e.g., Caddy-managed ACME or external client)"
	@echo "   3) When ready, replace 'issuer-available' with a real guard that verifies your chosen issuer."
	@exit 1

# Harden issue/renew so they never run by accident while issuer is absent
.PHONY: issue
issue: issuer-available  ## keep or remove the old delegate once a real issuer exists
	@$(run_as_root) $(CERTS_DEPLOY) issue

.PHONY: renew
renew: issuer-available  ## keep or remove the old delegate once a real issuer exists
	@$(run_as_root) $(CERTS_DEPLOY) renew FORCE=$(FORCE) ACME_FORCE=$(ACME_FORCE)

define deploy_with_status
	@$(run_as_root) $(CERTS_DEPLOY) deploy $(1)
	@if [ "$(1)" = "caddy" ]; then \
		echo "🔁 Reloading Caddy due to certificate change"; \
		$(run_as_root) /jffs/scripts/caddy-reload.sh; \
	fi
	@echo "🔄 Certificate deploy requested → $(1)"
endef

.PHONY: prepare
prepare: require-run-as-root fix-acme-perms
	@$(run_as_root) $(CERTS_DEPLOY) prepare

.PHONY: deploy-router
deploy-router: prepare
	$(call deploy_with_status,router)

define validate_with_status
	@$(run_as_root) $(CERTS_DEPLOY) validate $(1)
	@echo "🔁 $(1) validation OK"
endef

.PHONY: validate-caddy
validate-caddy:
	$(call validate_with_status,caddy)

.PHONY: validate-router
validate-router:
	$(call validate_with_status,router)

# disabled until issuer exists
.PHONY: all-caddy
all-caddy: renew prepare deploy-caddy validate-caddy

.PHONY: all-router
all-router: renew prepare deploy-router validate-router

# ACME_HOME is optional; only used if an issuer is explicitly provisioned.
ACME_HOME := /jffs/acme

.PHONY: fix-acme-perms
fix-acme-perms:
	@if [ -d "$(ACME_HOME)" ]; then \
		echo "[acme] fixing permissions"; \
		$(run_as_root) find "$(ACME_HOME)" -type f -name "*.key" -exec chmod 600 {} \; ; \
		$(run_as_root) find "$(ACME_HOME)" -type f ! -name "*.key" -exec chmod 644 {} \; ; \
		$(run_as_root) find "$(ACME_HOME)" -type d -exec chmod 700 {} \; ; \
		$(run_as_root) chown -R root:root "$(ACME_HOME)"; \
	fi

# ------------------------------------------------------------
# Bootstrap
# ------------------------------------------------------------

.PHONY: bootstrap
bootstrap: install-run-as-root install-caddy-reload install-certs install-ddns dnsmasq-cache certs-ensure firewall-install
	@echo "✅ Bootstrap complete"

# Ensure run-as-root exists before anything that needs privilege
.PHONY: require-run-as-root
require-run-as-root: | ssh-check
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		test -x "$(RUN_AS_ROOT)" || \
		( \
			echo "❌ run-as-root helper not found at $(RUN_AS_ROOT)"; \
			echo "👉 Run: make install-run-as-root"; \
			exit 1; \
		) \
	'

# ------------------------------------------------------------
# Caddy
# ------------------------------------------------------------
# ------------------------------------------------------------
# CADDY MANAGEMENT
# ------------------------------------------------------------
#
# DESIGN GOALS
# ------------
#   - Non-recursive: NO $(MAKE) or 'make' in any recipe
#   - Declarative ordering via Make dependencies only
#   - Correct under 'make -j'
#   - No timestamp lies for remote state
#
# TARGET ROLES
# ------------
#   - caddy-config:
#       * Pushes the Caddyfile to the router
#       * Validates the configuration
#       * Reloads the running Caddy process
#       * Does NOT manage certificates
#
#   - caddy:
#       * Full converge target
#       * Deploys certificates first (deploy-caddy)
#       * Then applies configuration (caddy-config)
#
# DEPENDENCY CONTRACTS
# --------------------
#   - firewall-started is a HARD prerequisite:
#       Caddy must never reload/start before firewall rules exist
#
#   - scripts-installed is an ORDER-ONLY prerequisite:
#       Helper scripts must exist before use, but must not
#       participate in rebuild decisions
#
#   - require-* targets are guards:
#       They validate invariants (arch, binary presence, privileges)
#       and do not perform state changes
#
# NOTE
# ----
#   The Caddyfile is NOT modeled as a Make target.
#   It lives on a remote system and is applied as an ACTION,
#   not a dependency, to avoid fake timestamps and rebuild loops.
# ------------------------------------------------------------
.PHONY: caddy-validate
caddy-validate: require-run-as-root firewall-started | scripts-installed
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		if [ ! -f "$(CADDYFILE_DST)" ]; then \
			echo "❌ Caddyfile not found at $(CADDYFILE_DST)"; \
			echo "👉 Run: make caddy"; \
			exit 1; \
		fi \
	'
	@$(run_as_root) $(CADDY_BIN) validate --config $(CADDYFILE_DST)

# ------------------------------------------------------------
# CADDY MANAGEMENT (CONSOLIDATED)
# ------------------------------------------------------------

.PHONY: install-caddy
install-caddy: | ssh-check
	@test -x $(SRC_SCRIPTS)/caddy || \
	( \
		echo "❌ Local Caddy binary missing at $(SRC_SCRIPTS)/caddy"; \
		echo "👉 Run: make caddy-download"; \
		exit 1; \
	)
	@echo "🔍 Ensuring Caddy binary on router..."
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/caddy,\
		$(CADDY_BIN))

.PHONY: push-caddyfile
push-caddyfile: caddy-fmt caddy-dirs firewall-started
	@echo "🚀 Pushing Caddyfile..."
	@scp -q -O -P $(ROUTER_SSH_PORT) $(CADDYFILE_SRC) $(ROUTER_HOST):$(CADDYFILE_DST)
	@echo "🔍 Validating configuration on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"$(CADDY_BIN) validate --config $(CADDYFILE_DST)"

.PHONY: restart-caddy
restart-caddy:
	@echo "🔁 Restarting Caddy..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"/jffs/scripts/caddy-reload.sh"


# 1. Local Download: Only runs if bin/caddy is missing locally
$(SRC_SCRIPTS)/caddy:
	@echo "🌐 Downloading custom Caddy (linux/arm64) + Infomaniak..."
	@mkdir -p $(SRC_SCRIPTS)
	@curl -L "https://caddyserver.com/api/download?os=linux&arch=arm64&p=github.com/caddy-dns/infomaniak" -o "$(SRC_SCRIPTS)/caddy"
	@chmod +x "$(SRC_SCRIPTS)/caddy"

# 3. Deployment Flow
.PHONY: deploy-caddy
deploy-caddy: prepare install-caddy install-caddy-reload caddy-config
	@echo "🚀 Caddy deployment complete"

.PHONY: caddy-config
caddy-config: caddy-fmt caddy-dirs $(SENTINEL_CADDY_BIN) firewall-started | install-caddy-reload
	@echo "🚀 Pushing Caddyfile..."
	@scp -q -O -P $(ROUTER_SSH_PORT) $(CADDYFILE_SRC) $(ROUTER_HOST):$(CADDYFILE_DST)
	@echo "🔍 Validating configuration using NEW binary..."
	@$(run_as_root) $(CADDY_BIN) validate --config $(CADDYFILE_DST)
	@echo "🔁 Reloading Caddy..."
	@$(run_as_root) $(ROUTER_SCRIPTS)/caddy-reload.sh

.PHONY: caddy
caddy: deploy-caddy caddy-config
	@echo "✨ Caddy fully converged"

.PHONY: caddy-status
caddy-status: | ssh-check
	@echo "🔍 Checking Caddy status..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		if [ ! -d /tmp/mnt/sda ]; then \
			echo "❌ External disk not mounted"; exit 1; \
		fi; \
		if [ ! -x "$(CADDY_BIN)" ]; then \
			echo "❌ Caddy binary missing or not executable at $(CADDY_BIN)"; exit 1; \
		fi; \
		if pidof caddy >/dev/null 2>&1; then \
			echo "✅ Caddy is running (PID: $$(pidof caddy))"; \
		else \
			echo "⚠️  Caddy is NOT running"; \
		fi; \
		echo "📦 Module Check:"; \
		if $(CADDY_BIN) list-modules | grep -q "dns.providers.infomaniak"; then \
			echo "  ✅ infomaniak plugin found"; \
		else \
			echo "  ❌ infomaniak plugin MISSING"; \
		fi \
	'

.PHONY: caddy-log
caddy-log: | ssh-check
	@echo "📜 Tailing Caddy logs..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"tail -f /tmp/mnt/sda/router/logs/caddy.log"

.PHONY: caddy-health
caddy-health: | ssh-check
	@echo "🩺 Checking Caddy health on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) ' \
		# External disk check \
		if [ ! -d /tmp/mnt/sda ]; then \
			echo '\''❌ External disk not mounted'\''; exit 1; \
		fi; \
		# Binary presence check \
		if [ ! -x "$(CADDY_BIN)" ]; then \
			echo '\''❌ Caddy binary missing at $(CADDY_BIN)'\''; exit 1; \
		fi; \
		# Process check \
		if pidof caddy >/dev/null 2>&1; then \
			echo '\''✅ Caddy process running'\''; \
		else \
			echo '\''⚠️  Caddy NOT running'\''; \
		fi; \
		# Config validation \
		if $(CADDY_BIN) validate --config $(CADDYFILE_DST) >/dev/null 2>&1; then \
			echo '\''✅ Caddyfile valid'\''; \
		else \
			echo '\''❌ Caddyfile INVALID'\''; \
		fi; \
	'

# ------------------------------------------------------------
# Architecture guard
# ------------------------------------------------------------

.PHONY: require-arm64
require-arm64: | ssh-check
	@arch="$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) uname -m)"; \
	if [ "$$arch" != "aarch64" ]; then \
		echo "❌ Unsupported router architecture: $$arch"; \
		echo "👉 Expected: aarch64 (ARM64)"; \
		echo "👉 This Makefile installs linux/arm64 binaries only"; \
		exit 1; \
	fi

# ------------------------------------------------------------
# Download Caddy
# ------------------------------------------------------------

.PHONY: caddy-download
caddy-download:
	@EXPECTED_SHA="7d11d11dc1bc68b1e38ded9d7d9370ad96f0dd2721139f8b145305c6d8dc3897"; \
	BIN="$(REPO_ROOT)$(SRC_SCRIPTS)/caddy"; \
	if [ -x "$$BIN" ]; then \
		CUR_SHA="$$(sha256sum "$$BIN" | awk '{print $$1}')"; \
		if [ "$$CUR_SHA" = "$$EXPECTED_SHA" ]; then \
			echo "✨ Caddy binary already present with expected hash"; \
			echo "🔐 SHA256: $$CUR_SHA"; \
			exit 0; \
		else \
			echo "⚠️  Caddy binary present but hash differs"; \
			echo "   current:  $$CUR_SHA"; \
			echo "   expected: $$EXPECTED_SHA"; \
		fi; \
	else \
		echo "ℹ️  Local Caddy binary not found"; \
	fi; \
	echo "🌐 Downloading Caddy with Infomaniak DNS plugin (~40s)..."; \
	tmpdir="$$(mktemp -d)"; \
	cd "$$tmpdir" && \
	curl -L \
		"https://caddyserver.com/api/download?os=linux&arch=arm64\
&p=github.com/caddy-dns/infomaniak" \
		-o caddy && \
	mkdir -p "$(REPO_ROOT)$(SRC_SCRIPTS)" && \
	mv caddy "$$BIN" && \
	chmod 755 "$$BIN" && \
	rm -rf "$$tmpdir"; \
	echo "🔐 SHA256:"; \
	sha256sum "$$BIN"; \
	echo "ℹ️  Version will be shown after deployment on router"; \
	echo "✅ Custom Caddy with Infomaniak plugin downloaded"

# ------------------------------------------------------------
# Postinstall tests
# ------------------------------------------------------------

.PHONY: test-postinstall
test-postinstall: ssh-check require-arm64 caddy-validate caddy-status
	@echo "✅ All router invariants validated"

.PHONY: test-preinstall
test-preinstall: ssh-check require-arm64
	@echo "✅ Pre-install invariants validated"

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

.PHONY: distclean
distclean: clean
	@echo "🧹 Removing downloaded binaries and tools..."
	@rm -rf $(SRC_SCRIPTS)/caddy $(TOOLS_DIR)

# ------------------------------------------------------------
# Install certificate scripts
# ------------------------------------------------------------

.PHONY: install-certs
install-certs: require-run-as-root | ssh-check
	@echo "🔐 Ensuring certificate helpers on router..."
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/certs-create.sh,\
		$(ROUTER_SCRIPTS)/certs-create.sh)
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/certs-deploy.sh,\
		$(ROUTER_SCRIPTS)/certs-deploy.sh)
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/generate-client-cert.sh,\
		$(ROUTER_SCRIPTS)/generate-client-cert.sh)
	$(call deploy_if_changed,\
		$(SRC_SCRIPTS)/gen-client-cert-wrapper.sh,\
		$(ROUTER_SCRIPTS)/gen-client-cert-wrapper.sh)
	@echo "🔐 Certificate helpers ensured"


# ------------------------------------------------------------
# Firewall: installed + started as prereqs for Caddy
# ------------------------------------------------------------

.PHONY: firewall-ensure
firewall-ensure: firewall-install | ssh-check
	@echo "🚦 Ensuring firewall rules are present..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		iptables -C INPUT -i eth0 -p tcp --dport 443 \
			-m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null || \
		/jffs/scripts/firewall-start \
	'
	@echo "✅ Firewall rules ensured"

.PHONY: firewall-install
firewall-install: | ssh-check require-run-as-root
	@echo "🔥 Checking firewall-start on router..."
	@LOCAL_SHA=$$(sha256sum $(SRC_SCRIPTS)/firewall-start | awk '{print $$1}'); \
	REMOTE_SHA=$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"sha256sum /jffs/scripts/firewall-start 2>/dev/null | awk '{print \$$1}'" || true); \
	if [ "$$LOCAL_SHA" != "$$REMOTE_SHA" ]; then \
		echo "🚀 Installing firewall-start to router..."; \
		scp -O -P $(ROUTER_SSH_PORT) \
			$(SRC_SCRIPTS)/firewall-start \
			$(ROUTER_HOST):/jffs/scripts/firewall-start; \
		ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
			"chmod +x /jffs/scripts/firewall-start"; \
		echo "✅ Firewall script updated"; \
	else \
		echo "✨ Firewall script already up-to-date"; \
	fi


.PHONY: firewall-started
firewall-started: firewall-ensure

.PHONY: firewall
firewall: firewall-ensure

# ------------------------------------------------------------
# Scripts bundle (order-only) for Caddy
# ------------------------------------------------------------

.PHONY: scripts-installed
scripts-installed: install-run-as-root install-caddy-reload install-certs
	@echo "🧩 All required scripts installed"

.PHONY: caddy-dirs
caddy-dirs: | ssh-check
	@echo "📁 Ensuring Caddy directories exist..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		mkdir -p \
			/etc/caddy \
			/var/lib/caddy \
			/tmp/mnt/sda/router/logs \
	'
	@echo "✅ Caddy directories ready"

.PHONY: caddy-fmt
caddy-fmt:
	@if ! command -v caddy >/dev/null 2>&1; then \
		echo "❌ Local Caddy not installed"; \
		echo "👉 Run: sudo apt-get update && sudo apt-get install -y caddy"; \
		exit 1; \
	fi
	@echo "🧹 Formatting local Caddyfile..."
	@caddy fmt --overwrite $(CADDYFILE_SRC)
	@echo "✨ Local Caddyfile formatted"

.PHONY: caddy-reload
caddy-reload:
	@echo "🔁 Reloading Caddy..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "/jffs/scripts/caddy-reload.sh"
