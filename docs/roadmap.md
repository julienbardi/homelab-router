<hash> docs/roadmap.md

<hash> Roadmap and Future Work

This document captures intentional future directions for the project.
It is not a promise or a schedule. It exists to make long‑term intent explicit
and to prevent accidental architectural drift.

---

<hash> Guiding Principles

All future work must preserve:

- Declarative intent in the control plane
- Deterministic execution
- Explicit invariants
- Recoverability without improvisation
- Operator‑grade ergonomics

Any change that weakens these principles is out of scope.

---

<hash> Near‑Term Goals

- Finalize WireGuard client onboarding automation
- Harden key rotation workflows
- Improve invariant validation coverage
- Expand documentation where logic is still implicit
- Reduce manual steps in recovery procedures

---

<hash> Medium‑Term Goals

- Introduce explicit client inventory outside the domain model
- Improve benchmarking automation and result capture
- Add regression detection for performance changes
- Further isolate experimental interfaces from production
- Simplify router replacement procedures

---

<hash> Long‑Term Goals

- Eliminate remaining single points of failure
- Support multi‑operator workflows
- Enable remote recovery without physical access
- Formalize contract testing for domain intent
- Treat the router as a fully disposable execution node

---

<hash> Explicit Non‑Goals

The following are intentionally out of scope:

- GUI‑driven configuration
- Dynamic or self‑modifying intent
- Implicit discovery or auto‑magic behavior
- Tight coupling to specific client OS behavior
- Turning this into a general‑purpose framework

---

<hash> Change Discipline

Roadmap updates must:

- Reflect architectural intent, not wishful thinking
- Be consistent with existing documentation
- Avoid introducing hidden assumptions

If a future idea cannot be explained clearly here, it is not ready.

---

<hash> Summary

This roadmap exists to preserve direction, not velocity.

Progress is measured by clarity, safety, and boring reliability.
