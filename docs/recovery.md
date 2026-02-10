# docs/recovery.md

# Recovery and Disaster Handling

This document describes how the system is recovered after failure, misconfiguration,
or hardware loss. Recovery is treated as a first‑class design concern.

The goal is deterministic restoration, not heroic debugging.

---

# Design Assumptions

Recovery relies on the following assumptions:

- Domain intent is authoritative and stored off the router
- Execution nodes are replaceable
- Scripts are idempotent
- No critical state exists only in RAM
- Manual recovery steps are documented

If any assumption is violated, recovery is considered incomplete.

---

# Failure Scenarios

The system explicitly supports recovery from:

- Router reboot or factory reset
- Router replacement
- NAS reboot or service restart
- Script regression
- WireGuard misconfiguration
- Client key compromise

Unsupported scenarios are treated as bugs.

---

# Router Loss or Reset

If the router is lost, reset, or replaced:

1. Flash firmware and enable SSH
2. Restore minimal access (LAN IP, credentials)
3. Mount NAS storage
4. Re‑deploy scripts via Makefile
5. Re‑apply configuration from domain intent
6. Validate invariants via preflight checks

No manual reconstruction of configuration is required.

---

# NAS Loss or Unavailability

If the NAS is unavailable:

- Production VPN on the router continues to function
- Benchmark interfaces are unavailable
- No configuration changes are permitted

Recovery requires restoring NAS availability before further changes.

---

# WireGuard Misconfiguration

If a WireGuard interface fails:

- Tear down the interface
- Re‑compile configuration from domain intent
- Re‑deploy deterministically
- Validate connectivity explicitly

Manual edits to live configuration are forbidden.

---

# Key Compromise

If a client key is suspected compromised:

- Revoke the client allocation
- Regenerate keys
- Re‑deploy server configuration
- Distribute new client configuration

Key rotation is performed by regeneration, not mutation.

---

# Script Regression

If a script introduces a regression:

- Roll back via Git
- Re‑deploy known‑good version
- Validate invariants
- Document the failure mode

Recovery must not rely on memory or ad‑hoc fixes.

---

# Invariant Validation

Recovery is complete only when:

- SSH preflight passes
- Domain constraints validate
- WireGuard interfaces are up
- Routing behaves as declared
- No warnings are emitted

Partial recovery is treated as failure.

---

# Summary

Recovery is not an afterthought.

The system is designed so that:

- Intent survives hardware
- Execution is repeatable
- Failure modes are bounded
- Recovery steps are explicit

If recovery requires improvisation, the design is incomplete.
