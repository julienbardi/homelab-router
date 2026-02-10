# docs/changelog.md

# Changelog and Intent Tracking

This document records intentional, user‑visible changes to the system’s
behavior, architecture, or invariants.

It does not replace Git history. It explains *why* changes were made.

---

# Versioning Model

This project does not follow semantic versioning.

Instead, changes are tracked by intent:

- Architectural changes
- Domain model changes
- Execution logic changes
- Invariant changes

Any change that alters assumptions must be recorded here.

---

# What Must Be Recorded

The following changes require an entry:

- Domain schema modifications
- New or removed invariants
- Changes to routing or AllowedIPs behavior
- Changes to trust or security boundaries
- Recovery procedure changes
- Removal of legacy behavior

Pure refactors without behavioral impact do not require entries.

---

# Entry Format

Each entry must include:

- Date
- Area affected
- Summary of change
- Rationale
- Impact on operators

Example:

`
2026‑02‑10
Area: AllowedIPs derivation
Change: Removed implicit IPv6 default route on Android clients
Rationale: Android ignored ::/0, causing inconsistent behavior
Impact: Android clients now receive IPv4‑only full tunnel
`

---

# Responsibility

The person making the change is responsible for documenting it.

If a change cannot be explained clearly, it is not ready to be merged.

---

# Relationship to Documentation

If a changelog entry contradicts documentation:

- Documentation must be updated
- Or the change must be reverted

Documentation is normative.

---

# Summary

This changelog exists to preserve intent over time.

If behavior changes without an entry here, the system is drifting.
