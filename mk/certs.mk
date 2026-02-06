# mk/certs.mk
# ------------------------------------------------------------
# CERTIFICATE LIFECYCLE MANAGEMENT
# ------------------------------------------------------------
#
# Responsibilities:
#   - Internal CA creation and rotation
#   - Certificate deployment to router services
#   - Validation and status inspection
#   - Client certificate generation
#
# Non-responsibilities:
#   - Certificate issuance via ACME (external concern)
#   - Service configuration (handled by service modules)
#
# Safety:
#   - Destructive operations require explicit confirmation
#   - Issuer absence is guarded explicitly
#
# Contracts:
#   - MUST NOT assume presence of ACME tooling
#   - MUST NOT invoke $(MAKE)
# ------------------------------------------------------------

define deploy_with_status
	@$(run_as_root) $(CERTS_DEPLOY) deploy $(1)
	@if [ "$(1)" = "caddy" ]; then \
		$(run_as_root) /jffs/scripts/caddy-reload.sh; \
	fi
endef

define validate_with_status
	@$(run_as_root) $(CERTS_DEPLOY) validate $(1)
endef

.PHONY: certs-create
certs-create: require-run-as-root
	@$(run_as_root) $(CERTS_CREATE)

.PHONY: certs-deploy
certs-deploy: require-run-as-root certs-create
	@$(run_as_root) $(CERTS_DEPLOY)

.PHONY: certs-ensure
certs-ensure: certs-deploy

.PHONY: certs-status
certs-status:
	@$(run_as_root) ls -l /jffs/ssl || true

.PHONY: certs-expiry
certs-expiry:
	@$(run_as_root) openssl x509 -in /etc/ssl/certs/homelab_bardi_CA.pem -noout -enddate

.PHONY: certs-rotate-dangerous
certs-rotate-dangerous:
	@read -p "Type YES to continue: " r && [ "$$r" = "YES" ]
	@$(run_as_root) $(CERTS_CREATE) --force
	@$(run_as_root) $(CERTS_DEPLOY)

.PHONY: deploy-router
deploy-router: router-prepare
	$(call deploy_with_status,router)

.PHONY: validate-router
validate-router:
	$(call validate_with_status,router)

.PHONY: validate-caddy
validate-caddy:
	$(call validate_with_status,caddy)
