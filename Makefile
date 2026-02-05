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

.NOTPARALLEL:
# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

ROUTER_HOST      := julie@10.89.12.1
ROUTER_SSH_PORT  := 2222
ROUTER_SCRIPTS   := /jffs/scripts
REPO_ROOT        := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ROUTER_USER      := $(word 1,$(subst @, ,$(ROUTER_HOST)))
ROUTER_ADDR      := $(word 2,$(subst @, ,$(ROUTER_HOST)))

# Source Paths (Explicit)
SRC_DDNS         := $(REPO_ROOT)ddns
SRC_CADDY        := $(REPO_ROOT)caddy
SRC_SCRIPTS      := jffs/scripts

DNSMASQ_CONF_ADD := /jffs/configs/dnsmasq.conf.add
DNS_CACHE_SIZE   := 10000
DNSMASQ_CACHE_LINE := cache-size=$(DNS_CACHE_SIZE)
DNSMASQ_CHANGED  := .dnsmasq-cache-changed

# Sentinels for local state tracking
SENTINEL_FW_INST := .firewall_installed
SENTINEL_FW_START := .firewall_started

CADDY_VERSION := 2.10.2
CADDY_SHA256  := 501e955fa634c5aab63247458c3ac655cfdd6cbf1e0436528f41248451c190ac

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

# ------------------------------------------------------------
# Help / entry points
# ------------------------------------------------------------

.PHONY: help
help:
	@echo "Homelab router Makefile — available targets:"
	@echo ""
	@echo "Bootstrap / setup:"
	@echo "  make bootstrap              Install helpers, DDNS, dnsmasq cache, and certificates"
	@echo "  make install-run-as-root    Install privilege execution helper on router"
	@echo ""
	@echo "DynDNS:"
	@echo "  make install-ddns           Install DynDNS script to router"
	@echo "  make test-ddns              Run DynDNS script manually on router"
	@echo ""
	@echo "dnsmasq:"
	@echo "  make dnsmasq-cache          Ensure dnsmasq cache configuration (restart if needed)"
	@echo "  make dnsmasq-show           Show current dnsmasq cache configuration"
	@echo ""
	@echo "Certificates:"
	@echo "  make certs-create           Create internal CA (idempotent)"
	@echo "  make certs-deploy           Deploy CA material"
	@echo "  make certs-ensure           Ensure CA exists and is deployed"
	@echo "  make certs-status           Show CA certificate status"
	@echo "  make certs-expiry           Show CA expiry information"
	@echo "  make certs-rotate-dangerous Rotate CA (DESTRUCTIVE, manual confirmation)"
	@echo ""
	@echo "  make issue                  Issue ACME certificates (requires external issuer)"
	@echo "  make renew                  Renew ACME certificates (requires external issuer)"
	@echo "  make prepare                Prepare certificates for deployment"
	@echo ""
	@echo "  make deploy-caddy           Deploy certificates to Caddy"
	@echo "  make deploy-router          Deploy certificates to router services"
	@echo "  make validate-caddy         Validate Caddy certificate deployment"
	@echo "  make validate-router        Validate router certificate deployment"
	@echo ""
	@echo "  make all-caddy              Renew, deploy, and validate Caddy certificates"
	@echo "  make all-router             Renew, deploy, and validate router certificates"
	@echo ""
	@echo "Client certificates:"
	@echo "  make gen-client-cert CN=<name> [FORCE=1]"
	@echo "  e.g. CN=julien-laptop, CN=android-phone"
	@echo ""
	@echo "Diagnostics / tooling:"
	@echo "  make doctor                 Validate router environment"
	@echo "  make lint                   Run checkmake on Makefile"
	@echo "  make clean                  Remove local state files"
	@echo "  make distclean              Remove downloaded binaries and tools"
	@echo "Caddy (router edge):"
	@echo "  make caddy-download         Download Caddy binary (linux/arm64) to bin/"
	@echo "  make caddy-install          Install Caddy binary to external disk"
	@echo "  make caddy-validate         Validate Caddyfile syntax"
	@echo "  make caddy                  Deploy Caddyfile, certificates, and reload Caddy"
	@echo "  make caddy-status           Check Caddy binary presence and process state"
	@echo "  make caddy-start            Start Caddy manually"
	@echo "  make caddy-stop             Stop Caddy manually"
	@echo "  make caddy-log              Tail Caddy logs"
	@echo "  make caddy-health           Full Caddy health check (binary, process, config)"
	@echo ""
	@echo "  make test-postinstall       Validate full router runtime state"
	@echo "  make firewall               Install and apply firewall rules (force re-apply)"
	@echo "  make firewall-installed     Ensure firewall script is installed (idempotent)"
	@echo "  make firewall-started       Ensure firewall rules are applied (idempotent)"
	@echo "  make all-full               Run 'all' + 'caddy' (Full Convergence)"

.PHONY: all
all: install-ddns dnsmasq-cache firewall-started

.PHONY: all-full
all-full: all caddy
	@echo "✅ Router and Caddy fully converged"

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
	@echo "🔐 Installing run-as-root helper on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "mkdir -p $(ROUTER_SCRIPTS)"
	@scp -q -O -P $(ROUTER_SSH_PORT) \
		$(SRC_SCRIPTS)/run-as-root.sh \
		$(ROUTER_HOST):$(RUN_AS_ROOT)
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "chmod 0755 $(RUN_AS_ROOT)"
	@echo "✅ run-as-root installed"

# ------------------------------------------------------------
# DynDNS
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns: | ssh-check
	@echo "📡 Installing DynDNS script on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"mkdir -p $(ROUTER_SCRIPTS)"
	@scp -q -O -P $(ROUTER_SSH_PORT) \
		"$(SRC_DDNS)/ddns-start" \
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

.PHONY: dnsmasq-ensure-config dnsmasq-restart-if-needed dnsmasq-cache

dnsmasq-ensure-config: | ssh-check
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
		touch $(DNSMASQ_CHANGED); \
	else \
		rm -f $(DNSMASQ_CHANGED); \
	fi

dnsmasq-restart-if-needed: dnsmasq-show | ssh-check
	@if [ -f "$(DNSMASQ_CHANGED)" ]; then \
		echo "🔄 Restarting dnsmasq..."; \
		ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "service restart_dnsmasq"; \
		rm -f $(DNSMASQ_CHANGED); \
		echo "✅ dnsmasq restarted"; \
	else \
		echo "ℹ️  No dnsmasq restart needed"; \
	fi

dnsmasq-cache: dnsmasq-restart-if-needed
	@echo "✅ dnsmasq cache reconciled"

# ------------------------------------------------------------
# Tooling
# ------------------------------------------------------------

.PHONY: clean
clean:
	@rm -f $(DNSMASQ_CHANGED) $(SENTINEL_FW_INST) $(SENTINEL_FW_START)
	@echo "🧹 Local state cleaned"

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

.PHONY: deploy-caddy
deploy-caddy: prepare
	$(call deploy_with_status,caddy)

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
bootstrap: install-run-as-root install-caddy-reload install-certs install-ddns dnsmasq-cache certs-ensure firewall-installed
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
caddy-validate: require-run-as-root require-caddy firewall-started | scripts-installed
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		if [ ! -f "$(CADDYFILE_DST)" ]; then \
			echo "❌ Caddyfile not found at $(CADDYFILE_DST)"; \
			echo "👉 Run: make caddy"; \
			exit 1; \
		fi \
	'
	@$(run_as_root) $(CADDY_BIN) validate --config $(CADDYFILE_DST)

# --- Caddy config deployment (no recursion, explicit deps) ---
.PHONY: caddy-config
caddy-config: firewall-started | scripts-installed
	@echo "🚀 Installing Caddyfile on router..."
	@$(run_as_root) mkdir -p $(dir $(CADDYFILE_DST))
	@$(run_as_root) chmod 0755 $(dir $(CADDYFILE_DST))
	# Copy Caddyfile from local repo to router
	@scp -q -O -P $(ROUTER_SSH_PORT) $(CADDYFILE_SRC) $(ROUTER_HOST):$(CADDYFILE_DST)
	@$(run_as_root) chmod 0644 $(CADDYFILE_DST)

	@echo "🔍 Validating deployed Caddyfile..."
	@$(run_as_root) $(CADDY_BIN) validate --config $(CADDYFILE_DST)

	@echo "🔁 Reloading Caddy due to config change..."
	@$(run_as_root) /jffs/scripts/caddy-reload.sh

	@echo "✅ Caddy config deployed and validated"

# --- Full Caddy converge target (certs + config), no recursive make ---
.PHONY: caddy
caddy: require-arm64 require-run-as-root require-caddy deploy-caddy caddy-config
	@echo "✅ Caddy converge complete (certs deployed + config applied)"

.PHONY: install-caddy-reload
install-caddy-reload: require-run-as-root
	@scp -q -O -P $(ROUTER_SSH_PORT) \
		$(SRC_SCRIPTS)/caddy-reload.sh \
		$(ROUTER_HOST):$(ROUTER_SCRIPTS)/caddy-reload.sh
	@$(run_as_root) chmod 0755 $(ROUTER_SCRIPTS)/caddy-reload.sh
	@echo "🔁 Caddy reload helper installed"

.PHONY: require-caddy
require-caddy: | ssh-check
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		test -x "$(CADDY_BIN)" || \
		( \
			echo "❌ caddy binary not found at $(CADDY_BIN)"; \
			echo "👉 Run: make caddy-download && make caddy-install"; \
			exit 1; \
		) \
	'

.PHONY: caddy-install
caddy-install: require-arm64 | ssh-check
	@echo "📦 Installing Caddy binary onto external disk..."

	@test -x $(SRC_SCRIPTS)/caddy || \
	( \
		echo "❌ local Caddy binary not found at $(SRC_SCRIPTS)/caddy"; \
		echo "👉 Run: make caddy-download"; \
		exit 1; \
	)

	@LOCAL_SHA="$$(sha256sum $(SRC_SCRIPTS)/caddy | awk '{print $$1}')"; \
	RESULT="$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		set -e; \
		if [ ! -d /tmp/mnt/sda ]; then \
			echo "ERROR:disk-not-mounted"; exit 0; \
		fi; \
		mkdir -p /tmp/mnt/sda/router/bin; \
		chmod 0755 /tmp/mnt/sda/router/bin; \
		if [ -x "$(CADDY_BIN)" ]; then \
			REMOTE_SHA="$$(sha256sum $(CADDY_BIN) | awk "{print \$$1}")"; \
		else \
			REMOTE_SHA=""; \
		fi; \
		if [ "$$REMOTE_SHA" = "'"$$LOCAL_SHA"'" ]; then \
			echo "UP-TO-DATE"; \
		else \
			echo "UPDATE"; \
		fi \
	')"; \
	case "$$RESULT" in \
		UP-TO-DATE) \
			echo "✅ Caddy binary already up to date"; \
			;; \
		UPDATE) \
			echo "→ Updating Caddy binary (USB copy, ~30–120s)…"; \
			scp -O -P $(ROUTER_SSH_PORT) $(SRC_SCRIPTS)/caddy $(ROUTER_HOST):$(CADDY_BIN); \
			ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) "chmod 755 $(CADDY_BIN)"; \
			echo "✅ Caddy installed at $(CADDY_BIN)"; \
			;; \
		*) \
			echo "❌ Unexpected result from router: $$RESULT"; \
			exit 1; \
			;; \
	esac

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
			echo "✅ Caddy is running"; \
		else \
			echo "⚠️  Caddy is NOT running"; \
		fi; \
	'

.PHONY: caddy-start
caddy-start: | ssh-check require-caddy
	@echo "🚀 Starting Caddy on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		$(CADDY_BIN) run --config $(CADDYFILE_DST) --adapter caddyfile & \
	'
	@echo "✅ Caddy started"

.PHONY: caddy-stop
caddy-stop: | ssh-check
	@echo "🛑 Stopping Caddy on router..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		killall caddy 2>/dev/null || echo "ℹ️  Caddy not running" \
	'
	@echo "✅ Caddy stopped"

.PHONY: caddy-log
caddy-log: | ssh-check
	@echo "📜 Tailing Caddy logs..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"tail -f /tmp/mnt/sda/router/logs/caddy.log"

.PHONY: caddy-health
caddy-health: | ssh-check
	@echo "🩺 Checking Caddy health..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) '\
		if [ ! -d /tmp/mnt/sda ]; then \
			echo "❌ External disk not mounted"; exit 1; \
		fi; \
		if [ ! -x "$(CADDY_BIN)" ]; then \
			echo "❌ Caddy binary missing at $(CADDY_BIN)"; exit 1; \
		fi; \
		if pidof caddy >/dev/null 2>&1; then \
			echo "✅ Caddy process running"; \
		else \
			echo "⚠️  Caddy NOT running"; \
		fi; \
		$(CADDY_BIN) validate --config $(CADDYFILE_DST) >/dev/null 2>&1 && \
			echo "✅ Caddyfile valid" || \
			echo "❌ Caddyfile INVALID"; \
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
	@echo "🌐 Downloading Caddy v$(CADDY_VERSION) (linux/arm64)..."
	@tmpdir="$$(mktemp -d)"; \
	cd "$$tmpdir" && \
	curl -L \
		"https://github.com/caddyserver/caddy/releases/download/v$(CADDY_VERSION)/caddy_$(CADDY_VERSION)_linux_arm64.tar.gz" \
		-o caddy.tar.gz && \
	echo "$(CADDY_SHA256)  caddy.tar.gz" | sha256sum -c - && \
	tar -xzf caddy.tar.gz && \
	mkdir -p "$(REPO_ROOT)$(SRC_SCRIPTS)" && \
	mv caddy "$(REPO_ROOT)$(SRC_SCRIPTS)/caddy" && \
	chmod 755 "$(REPO_ROOT)$(SRC_SCRIPTS)/caddy" && \
	rm -rf "$$tmpdir"
	@echo "✅ Caddy v$(CADDY_VERSION) downloaded and verified"

# ------------------------------------------------------------
# Postinstall tests
# ------------------------------------------------------------

.PHONY: test-postinstall
test-postinstall: ssh-check require-arm64 require-caddy caddy-validate caddy-status
	@echo "✅ All router invariants validated"

.PHONY: test-preinstall
test-preinstall: ssh-check require-arm64
	@echo "✅ Pre-install invariants validated"

.PHONY: test
test: test-preinstall

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
install-certs: require-run-as-root
	@echo "🔐 Installing certificate helpers..."
	@scp -q -O -P $(ROUTER_SSH_PORT) \
		$(SRC_SCRIPTS)/certs-create.sh \
		$(SRC_SCRIPTS)/certs-deploy.sh \
		$(SRC_SCRIPTS)/generate-client-cert.sh \
		$(SRC_SCRIPTS)/gen-client-cert-wrapper.sh \
		$(ROUTER_HOST):$(ROUTER_SCRIPTS)/
	@$(run_as_root) chmod 0755 \
		$(ROUTER_SCRIPTS)/certs-create.sh \
		$(ROUTER_SCRIPTS)/certs-deploy.sh \
		$(ROUTER_SCRIPTS)/generate-client-cert.sh \
		$(ROUTER_SCRIPTS)/gen-client-cert-wrapper.sh
	@echo "🔐 Certificate helpers installed"

# ------------------------------------------------------------
# Firewall: installed + started as prereqs for Caddy
# ------------------------------------------------------------

# Only SCP if the local source changed or marker is missing
$(SENTINEL_FW_INST): $(SRC_SCRIPTS)/firewall-start | ssh-check require-run-as-root
	@echo "🔥 Installing firewall-start to router..."
	@scp -O -P $(ROUTER_SSH_PORT) \
		$(SRC_SCRIPTS)/firewall-start \
		$(ROUTER_HOST):/jffs/scripts/firewall-start
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"chmod +x /jffs/scripts/firewall-start"
	@touch $@
	@echo "✅ Firewall script installed"

# Only run remote script if it was just installed or marker missing
$(SENTINEL_FW_START): $(SENTINEL_FW_INST) | ssh-check
	@echo "🚦 Ensuring firewall rules are applied..."
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		"/jffs/scripts/firewall-start || { echo '❌ Failed to apply firewall rules'; exit 1; }"
	@touch $@
	@echo "✅ Firewall rules applied"

# Phony targets for manual overrides
.PHONY: firewall-installed
firewall-installed: $(SENTINEL_FW_INST)

.PHONY: firewall-started
firewall-started: $(SENTINEL_FW_START)

# Alias for manual forcing (removes stamp, then runs)
.PHONY: firewall
firewall:
	@echo "🔄 Forcing firewall re-apply..."
	@rm -f $(SENTINEL_FW_START)
	@$(MAKE) $(SENTINEL_FW_START)

# ------------------------------------------------------------
# Scripts bundle (order-only) for Caddy
# ------------------------------------------------------------

.PHONY: scripts-installed
scripts-installed: install-run-as-root install-caddy-reload install-certs
	@echo "🧩 All required scripts installed"