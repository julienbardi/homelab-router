# Determine the absolute path to the directory containing this Makefile
REPO_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Default target
.PHONY: help
help:
    @echo "Available targets:"
    @echo "  make install-ddns     Install DynDNS script to /jffs/scripts"
    @echo "  make test-ddns        Run DynDNS script manually for verification"
    @echo "  make doctor           Validate router environment (basic checks)"

# ------------------------------------------------------------
# DynDNS installation
# ------------------------------------------------------------

.PHONY: install-ddns
install-ddns:
    @echo "📡 Installing DynDNS script..."
    mkdir -p /jffs/scripts
    cp "$(REPO_ROOT)/ddns/ddns-start" /jffs/scripts/ddns-start
    chmod 755 /jffs/scripts/ddns-start
    @echo "📁 Ensure your secrets exist at /jffs/scripts/.ddns_confidential"
    @echo "✨ DynDNS installation complete."

# ------------------------------------------------------------
# DynDNS test
# ------------------------------------------------------------

.PHONY: test-ddns
test-ddns:
    @echo "🧪 Running DynDNS script manually..."
    /jffs/scripts/ddns-start

# ------------------------------------------------------------
# Basic environment checks
# ------------------------------------------------------------

.PHONY: doctor
doctor:
    @echo "🩺 Running environment checks..."
    @test -d /jffs/scripts || echo "⚠️  Missing /jffs/scripts directory"
    @test -f /jffs/scripts/ddns-start || echo "⚠️  DynDNS script not installed"
    @test -f /jffs/scripts/.ddns_confidential || echo "⚠️  Missing secrets file"
    @echo "✨ Doctor check complete."
