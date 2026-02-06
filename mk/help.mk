.PHONY: help
help:
	@echo "Homelab router Makefile — available targets:"
	@echo
	@echo "Bootstrap / setup:"
	@echo "  make bootstrap              Install helpers, DDNS, dnsmasq cache, firewall"
	@echo "  make install-run-as-root    Install privilege execution helper on router"
	@echo
	@echo "Connectivity / access:"
	@echo "  make ssh-check              Verify non-interactive SSH access to router"
	@echo
	@echo "Health & diagnostics:"
	@echo "  make router-health          Read-only router health check"
	@echo "  make router-health-strict   Enforce strict security invariants"
	@echo "  make doctor                 Validate router environment"
	@echo
	@echo "DynDNS:"
	@echo "  make install-ddns           Install DynDNS script to router"
	@echo "  make test-ddns              Run DynDNS script manually on router"
	@echo
	@echo "dnsmasq:"
	@echo "  make dnsmasq-cache          Ensure dnsmasq cache configuration"
	@echo "  make dnsmasq-show           Show current dnsmasq cache configuration"
	@echo
	@echo "Certificates:"
	@echo "  make certs-create           Create internal CA (idempotent)"
	@echo "  make certs-deploy           Deploy CA material"
	@echo "  make certs-ensure           Ensure CA exists and is deployed"
	@echo "  make certs-status           Show CA certificate status"
	@echo "  make certs-expiry           Show CA expiry information"
	@echo "  make certs-rotate-dangerous Rotate CA (DESTRUCTIVE, manual confirmation)"
	@echo
	@echo "  make issue                  Issue ACME certificates"
	@echo "  make renew                  Renew ACME certificates"
	@echo "  make router-prepare         Prepare certificates for deployment"
	@echo
	@echo "  make deploy-caddy           Deploy certificates to Caddy"
	@echo "  make deploy-router          Deploy certificates to router services"
	@echo "  make validate-caddy         Validate Caddy certificate deployment"
	@echo "  make validate-router        Validate router certificate deployment"
	@echo
	@echo "Caddy (router edge):"
	@echo "  make caddy-download         Download Caddy binary (linux/arm64)"
	@echo "  make caddy-install          Install Caddy binary to external disk"
	@echo "  make caddy-validate         Validate Caddyfile syntax"
	@echo "  make caddy                  Deploy Caddyfile, certificates, and reload"
	@echo "  make caddy-status           Check Caddy binary presence and process state"
	@echo "  make caddy-start            Start Caddy manually"
	@echo "  make caddy-stop             Stop Caddy manually"
	@echo "  make caddy-log              Tail Caddy logs"
	@echo "  make caddy-health           Full Caddy health check"
	@echo
	@echo "Firewall:"
	@echo "  make firewall               Install and apply firewall rules"
	@echo "  make firewall-install       Ensure firewall script is installed"
	@echo "  make firewall-started       Ensure firewall rules are applied"
	@echo
	@echo "Maintenance:"
	@echo "  make clean                  Remove local state files"
	@echo "  make distclean              Remove downloaded binaries and tools"
