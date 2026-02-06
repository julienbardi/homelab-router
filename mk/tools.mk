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

SPELLCHECK_FILES := *.md
SPELLCHECK_MAKEFILES := Makefile mk/*.mk

.PHONY: lint
lint: tools
	@$(CHECKMAKE) Makefile || true

.PHONY: tools
tools: $(CHECKMAKE)

$(CHECKMAKE):
	@mkdir -p $(TOOLS_DIR)
	@GOBIN=$(abspath $(TOOLS_DIR)) \
		go install github.com/checkmake/checkmake/cmd/checkmake@latest

# ------------------------------------------------------------
# Spell checking (local only)
# ------------------------------------------------------------

.PHONY: spellcheck
spellcheck: require-aspell
	@echo "🔤 Spellchecking files (interactive)"
	@for f in $(SPELLCHECK_FILES); do \
		echo "→ $$f"; \
		aspell check "$$f"; \
	done

.PHONY: spellcheck-comments
spellcheck-comments: require-aspell
	@echo "🔤 Spellchecking Makefile comments only"
	@sed -n 's/^[[:space:]]*#//p' $(SPELLCHECK_MAKEFILES) | \
		aspell list | sort -u

.PHONY: require-aspell
require-aspell:
	@command -v aspell >/dev/null 2>&1 || \
	( \
		echo "❌ aspell is not installed"; \
		echo "   Install it with:"; \
		echo "     sudo apt install aspell"; \
		exit 1; \
	)

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

.PHONY: distclean
distclean:
	@rm -rf $(SRC_SCRIPTS)/caddy $(TOOLS_DIR)
