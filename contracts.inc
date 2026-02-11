===============================================================================
WireGuard Control Plane — Global Contracts
===============================================================================

This file defines all non-negotiable invariants for the WireGuard control plane.

It is documentation-as-law.
It contains no executable logic.
It MUST be kept in Git and reviewed like code.

All compiler, renderer, checker, and deployment scripts MUST comply with
these contracts.


-------------------------------------------------------------------------------
CONTRACT: Canonical storage & disaster recovery
-------------------------------------------------------------------------------

All canonical intent MUST reside on persistent router storage under /jffs/scripts/.

Canonical files:
  - domain.yaml      (domain definitions only)
  - contracts.inc    (this file)
  - Makefile         (orchestration only)

Runtime devices (router, clients) are disposable.
The entire system MUST be reconstructible from NAS backups alone.

WSL is a control-plane execution environment, NOT a source of truth.


-------------------------------------------------------------------------------
CONTRACT: Enumeration model
-------------------------------------------------------------------------------

The system enumerates the full valid state space:

    nodes × interfaces × profiles

There are:
  - no grants
  - no allow-lists
  - no selective enablement

Invalid combinations are excluded ONLY by hard constraints.

All valid combinations MUST be representable in the compiled dump.


-------------------------------------------------------------------------------
CONTRACT: Compiled dumps
-------------------------------------------------------------------------------

The following files are materialized database snapshots:

  - plan.tsv
  - alloc.tsv
  - keys.tsv

Properties:
  - Deterministic
  - Complete (no hidden runtime state)
  - Flat and relational
  - Excel-friendly
  - Never edited by hand
  - Authoritative once generated

If a configuration exists at runtime, it MUST exist in the dump.

Dump emission is OPTIONAL and controlled by:

    WG_DUMP=1

When WG_DUMP is unset or 0, dumps MUST NOT be written.


-------------------------------------------------------------------------------
CONTRACT: TSV encoding
-------------------------------------------------------------------------------

All dump files are UTF-8 encoded TSV with:

  - ASCII TAB (0x09) as field delimiter
  - LF (0x0A) as line terminator
  - No quoting
  - No escaping

Forbidden inside any field:

  - ASCII NUL (0x00)
  - TAB (0x09)
  - LF (0x0A)
  - CR (0x0D)

Quotes (", ') have NO special meaning.

Any violation MUST abort compilation loudly.


-------------------------------------------------------------------------------
CONTRACT: Deterministic ordering
-------------------------------------------------------------------------------

All dump rows MUST be emitted in a stable, deterministic order.

Sorting keys MUST be explicit and consistent across runs.

This guarantees:
  - clean diffs
  - reliable drift detection
  - trustworthy Excel inspection


-------------------------------------------------------------------------------
CONTRACT: Profiles
-------------------------------------------------------------------------------

Profiles are named routing intents.

Properties:
  - Textual identifiers with documented meaning
  - Not OS-specific
  - Not user-specific
  - Not grants
  - Not selections

Profiles describe intent ONLY.
Realization happens at render time.


-------------------------------------------------------------------------------
CONTRACT: Interfaces
-------------------------------------------------------------------------------

The 'iface' field uniquely identifies the WireGuard server endpoint.

There is NO additional server dimension.

Examples:
  - wg1..wg15  → NAS-hosted WireGuard servers
  - wgs        → Router-hosted WireGuard server

All server identity, keys, firewall rules, routing, and deployment
are derived exclusively from 'iface'.


-------------------------------------------------------------------------------
CONTRACT: Key lifecycle
-------------------------------------------------------------------------------

Client keys are scoped to:

    (base, iface)

Keys are:
  - generated idempotently
  - never rotated implicitly

Profile or OS changes MUST NOT affect key identity.


-------------------------------------------------------------------------------
CONTRACT: Renderers
-------------------------------------------------------------------------------

Renderers are dumb consumers of plan.tsv.

Renderers MUST perform:
  - no address math
  - no policy inference
  - no intent resolution

All intent MUST be resolved at compile time.


-------------------------------------------------------------------------------
CONTRACT: Wiring order
-------------------------------------------------------------------------------

WireGuard is the foundational layer.

Dependency order:

  1. WireGuard (identity, routing domains, interfaces)
  2. Firewall / NAT (keyed on WG interfaces)
  3. Higher-level services (e.g. Caddy)

No service above WireGuard may influence WireGuard intent.


===============================================================================
End of contracts.inc
===============================================================================
