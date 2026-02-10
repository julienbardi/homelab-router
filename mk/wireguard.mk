# mk/wireguard.mk
# ------------------------------------------------------------
# WireGuard control plane
# ------------------------------------------------------------
#
# Purpose:
#   - Execute WireGuard control-plane compilers on the router
#   - Validate and optionally dump derived state
#
# Contract:
#   - Scripts execute on the router, never locally
#   - No implicit execution
#   - No runtime convergence here
# ------------------------------------------------------------

.PHONY: wg-deploy
wg-deploy:
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) 'mkdir -p $(ROUTER_SCRIPTS)'
	@set -eu; \
	for f in wg-compile-domain.sh wg-compile-alloc.sh wg-compile-keys.sh; do \
		src='$(SRC_SCRIPTS)/'$$f; \
		dst='$(ROUTER_SCRIPTS)/'$$f; \
		lh="$$(sha256sum "$$src" | awk '{print $$1}')"; \
		rh="$$(ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
			"sha256sum '$$dst' 2>/dev/null" | awk '{print $$1}' || true)"; \
		if [ -n "$$rh" ] && [ "$$lh" = "$$rh" ]; then \
			echo "✅ $$f unchanged"; \
		else \
			echo "🚀 deploying $$f"; \
			ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
				"cat > '$$dst' && chmod +x '$$dst'" < "$$src"; \
		fi; \
	done

.PHONY: wg-check
wg-check: wg-deploy
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'$(ROUTER_SCRIPTS)/wg-compile-domain.sh'
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'$(ROUTER_SCRIPTS)/wg-compile-alloc.sh'
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'$(ROUTER_SCRIPTS)/wg-compile-keys.sh'
	@echo "✅ WireGuard control-plane check passed"

.PHONY: wg-dump
wg-dump:
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'WG_DUMP=1 $(ROUTER_SCRIPTS)/wg-compile-domain.sh'
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'WG_DUMP=1 $(ROUTER_SCRIPTS)/wg-compile-alloc.sh'
	@ssh -p $(ROUTER_SSH_PORT) $(ROUTER_HOST) \
		'WG_DUMP=1 $(ROUTER_SCRIPTS)/wg-compile-keys.sh'
	@echo "📦 WireGuard control-plane dumps generated"
