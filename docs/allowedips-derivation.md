# docs/allowedips-derivation.md

# AllowedIPs Derivation Rules

This document describes how WireGuard AllowedIPs are derived from the domain
model. These rules are implemented in shell scripts and renderers; they are
documented here to make intent explicit and stable.

This file documents logic, not configuration.

---

# Scope

This document explains:

- How profiles influence routing intent
- How interface capabilities constrain routing
- How AllowedIPs differ between server and client
- Where OS-specific behavior applies

This document does not define:

- Domain schema
- Client inventory
- Benchmarking logic
- Firewall or NAT behavior

---

# Inputs to AllowedIPs Derivation

AllowedIPs are derived from the following domain elements:

- Interface:
  - lan_subnets
  - vpn_subnet
  - internet
  - ipv6
- Profile:
  - lan
  - internet
- Client OS (renderer input, not domain data)

---

# Conceptual Model

AllowedIPs express *what traffic is routed through the tunnel*.

They are not symmetric:

- Server AllowedIPs describe *which peer addresses are accepted*
- Client AllowedIPs describe *which destinations are routed*

---

# Server-Side AllowedIPs

On the server, AllowedIPs are always minimal.

Rules:

- Each peer is assigned exactly one VPN address
- Server AllowedIPs for a peer include:
  - the peer’s VPN IPv4 address
  - optionally the peer’s VPN IPv6 address
- No LAN or Internet routes appear on the server side

Example (conceptual):

`AllowedIPs = peer_vpn_ipv4[/32], peer_vpn_ipv6[/128]`

This is invariant across profiles and OS.

---

# Client-Side AllowedIPs

Client AllowedIPs depend on profile intent and interface capability.

---

# Split Tunnel Profile

Profile intent:

- lan: true
- internet: false

Derived behavior:

- Route LAN subnets through the tunnel
- Do not route default Internet traffic

Client AllowedIPs include:

- All interface lan_subnets (IPv4 and IPv6 if enabled)

They do not include:

- 0.0.0.0/0
- ::/0

---

# Full Tunnel Profile

Profile intent:

- lan: true
- internet: true

Derived behavior:

- Route all traffic through the tunnel

Client AllowedIPs include:

- All interface lan_subnets
- 0.0.0.0/0
- ::/0 (if IPv6 is enabled)

---

# Interface Capability Constraints

Profiles are validated against interface capabilities.

Rules:

- If profile.internet is true, interface.internet must be true
- If profile requests IPv6 routes, interface.ipv6 must be true
- Invalid combinations are rejected at compile time

---

# OS-Specific Handling

Client operating systems differ in how they interpret routes.

Examples:

- Windows may require explicit LAN CIDRs
- Android may ignore IPv6 default routes
- macOS may require split IPv6 handling
- Linux may support policy routing or table isolation

These differences are handled in renderer logic.

They do not affect domain intent.

---

# Why OS Is Not Modeled

Client OS is intentionally excluded from the domain model because:

- It is an implementation detail
- It changes independently of topology
- Encoding it would pollute policy with mechanics
- Renderer logic already handles OS differences

The domain model expresses *what should happen*.
Renderers decide *how to make it happen*.

---

# Summary

- AllowedIPs are derived, never declared
- Server and client AllowedIPs serve different purposes
- Profiles express routing intent
- Interfaces constrain what is possible
- OS-specific behavior lives in renderers
- The domain model remains stable and declarative
