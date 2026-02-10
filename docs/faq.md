# docs/faq.md

# Frequently Asked Questions

This document answers recurring questions about the design, scope, and
boundaries of this repository. The answers here are normative.

---

# Why is domain.yaml private?

domain.yaml contains real topology, addresses, and security‑relevant intent.
It is authoritative and environment‑specific.

domain.example.yaml exists to document schema and semantics without exposing
real infrastructure.

---

# Why are AllowedIPs not declared in the domain model?

AllowedIPs are derived state.

They depend on:
- profile intent
- interface capability
- client operating system behavior

Encoding them in the domain model would mix intent with mechanics and make the
model brittle.

---

# Why are client operating systems not modeled?

Client OS is an implementation detail.

It changes independently of topology and policy. Renderer logic already handles
OS‑specific behavior. Modeling it would pollute intent with quirks.

---

# Why are servers addressed by IP instead of hostname?

Servers are part of the control and execution plane.

They require:
- determinism
- stability
- zero dependency on DNS

DNS is reserved for public endpoints only.

---

# Why does the NAS host WireGuard servers?

The NAS hosts additional WireGuard interfaces to enable:

- benchmarking
- experimentation
- kernel vs user‑space comparison
- isolation from production VPN traffic

The NAS never routes production traffic.

---

# Why is wg0 special?

wg0 is reserved for the production WireGuard interface on the router.

All other interfaces (wg1…wg15) are non‑production and may be destroyed or
recreated freely.

---

# Why is everything driven by Make?

Make provides:

- explicit dependency ordering
- reproducible workflows
- discoverable entry points
- operator‑friendly ergonomics

It is used as an orchestration layer, not a build system.

---

# Why are GUI changes discouraged?

GUI changes are:

- non‑auditable
- non‑reproducible
- difficult to review
- easy to forget

All meaningful changes must be encoded in scripts or intent.

---

# Why is recovery documented so explicitly?

Recovery is a design requirement.

If recovery requires improvisation, the system is incomplete. Documentation
exists to ensure recovery is deterministic and boring.

---

# Can this be generalized or reused?

The ideas can be reused freely.

The implementation is opinionated and tailored to this homelab. Expect to adapt
concepts rather than copy code verbatim.

---

# Summary

If a question arises that is not answered here or in other documentation, it
should be documented.

Implicit knowledge is treated as technical debt.
