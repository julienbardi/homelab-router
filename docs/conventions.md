# docs/conventions.md

# Operational Conventions

This document defines the operational conventions enforced across this
repository. These conventions are not stylistic preferences; they encode
assumptions relied upon by scripts, Make targets, and operators.

Violating these conventions is considered a bug.

---

# Naming Conventions

- WireGuard interfaces are named wg0, wg1, wg2, …
- wg0 is reserved for the production router interface
- wg1…wg15 are reserved for NAS‑hosted benchmark interfaces
- Server identifiers are lowercase and stable (router, nas)
- Profile names describe intent, not mechanics (profile-split, profile-full)

---

# File Placement

- domain.yaml is authoritative and private
- domain.example.yaml documents schema only
- Router‑side scripts live under jffs/scripts/
- Makefile fragments live under mk/
- Generated artifacts must never be committed
- Documentation lives exclusively under docs/

---

# Script Behavior

All scripts must:

- Fail loudly and early
- Validate preconditions explicitly
- Emit actionable error messages
- Avoid silent fallback behavior
- Be idempotent where possible

Scripts must not:

- Assume ambient state
- Modify unrelated configuration
- Hide failures behind warnings

---

# Makefile Conventions

- Each target performs exactly one logical action
- Targets must be safe to re‑run
- Preconditions are validated before execution
- Output must be operator‑oriented, not decorative
- No ambiguous progress indicators are allowed

---

# Output Conventions

- Icons are used only as meaningful state markers
- No ellipses or spinner‑style output
- Success and failure states must be unambiguous
- Errors must explain what failed and why

---

# Failure Semantics

- Partial success is treated as failure
- Any violated invariant aborts execution
- Recovery steps must be explicit
- No script may leave the system in an unknown state

---

# Change Discipline

- Intent changes require domain updates
- Logic changes require script updates
- Boundary changes require documentation updates
- All three must remain consistent

---

# Summary

These conventions exist to preserve determinism, auditability, and operator
trust.

If a change feels convenient but violates a convention, the convention wins.
