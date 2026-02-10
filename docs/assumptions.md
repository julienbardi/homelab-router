# docs/assumptions.md

# Explicit Assumptions

This document records the assumptions that the system relies on. These
assumptions are structural. If any of them stop being true, the design must be
revisited.

Assumptions are not optimizations. They are contracts.

---

# Infrastructure Assumptions

- The router and NAS are physically controlled
- The LAN is trusted
- The NAS is reachable from the router
- SSH access to execution nodes is available
- Storage on the NAS is persistent and backed up

If any assumption fails, recovery procedures apply.

---

# Operational Assumptions

- All meaningful changes go through Git
- Scripts are the only supported mutation mechanism
- GUI changes are temporary and must be reconciled
- Operators read and trust script output
- Preflight checks are authoritative

Manual intervention outside scripts is considered exceptional.

---

# Domain Model Assumptions

- domain.yaml is the single source of truth
- domain.example.yaml documents schema only
- Intent is stable relative to implementation
- Derived state is disposable
- Invalid combinations are rejected early

The domain model must remain declarative.

---

# Networking Assumptions

- WireGuard is the only VPN technology in use
- LAN subnets are stable
- VPN subnets do not overlap LAN subnets
- Public endpoints may be dynamic
- Internal management IPs are static

Violating these assumptions requires explicit redesign.

---

# Client Assumptions

- Clients may be compromised
- Clients are not trusted with routing authority
- Client OS behavior varies
- Client configuration is regenerated, not patched

Client convenience never overrides safety.

---

# Benchmarking Assumptions

- Benchmark interfaces are disposable
- Benchmark results are comparative, not absolute
- Benchmarking must not affect production traffic
- Performance regressions are meaningful signals

Benchmarking is a diagnostic tool, not a goal.

---

# Change Assumptions

- Changes are intentional
- Breaking changes are documented
- Documentation is normative
- Silence is not consent

If behavior changes without documentation, it is a defect.

---

# Summary

These assumptions define the operating envelope of the system.

If an assumption becomes uncomfortable, it must be surfaced and addressed,
not worked around.
