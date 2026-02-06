# mk/tools.mk
# ------------------------------------------------------------
# LOCAL DEVELOPER TOOLING
# ------------------------------------------------------------
#
# Responsibilities:
#   - Linting and style checks
#   - Bootstrapping local tools (checkmake)
#   - Local cleanup of generated artifacts
#
# Scope:
#   - Local machine only
#   - MUST NOT touch router state
#
# Contracts:
#   - Safe to run in parallel
#   - No SSH or remote side effects
# ------------------------------------------------------------
.PHONY: lint
lint: tools
	@$(CHECKMAKE) Makefile || true

.PHONY: tools
tools: $(CHECKMAKE)

$(CHECKMAKE):
	@mkdir -p $(TOOLS_DIR)
	@GOBIN=$(abspath $(TOOLS_DIR)) \
		go install github.com/checkmake/checkmake/cmd/checkmake@latest

.PHONY: distclean
distclean:
	@rm -rf $(SRC_SCRIPTS)/caddy $(TOOLS_DIR)
