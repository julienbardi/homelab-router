# Domain Model

This document describes the conceptual model used to define WireGuard topology,
policy, and intent in this repository.

The domain model is intentionally declarative. It expresses *what exists* and
*what is allowed*, not *how it is implemented*. All runtime behavior, OS-specific
logic, and WireGuard mechanics are derived later by compiler and renderer scripts.

---

## Scope and Non‑Goals

The domain model **does** describe:

- Which machines can host WireGuard servers
- Which WireGuard interfaces exist
- Where those interfaces run
- Which subnets are reachable
- Which access profiles exist
- Which profiles are allowed on which interfaces

The domain model **does not** describe:

- Client operating systems (Windows, Linux, Android, macOS)
- WireGuard `AllowedIPs`
- Routing tables or firewall rules
- NAT behavior
- Performance tuning
- Benchmarking logic
- OS‑specific quirks or workarounds

Those concerns belong to compiler and renderer logic.

---

## Top‑Level Structure

The canonical domain definition is stored in `domain.yaml` (private).
A synthetic, non‑routable example is provided as `domain.example.yaml`.

Top‑level sections:

- `servers`
- `nodes`
- `interfaces`
- `profiles`
- `constraints`

Each section has a single responsibility.

---

## Servers

```yaml
servers:
  router:
    mgmt_ip:
      ipv4: 192.168.1.1
      ipv6: fd00:1::1
```

A server represents a machine capable of running WireGuard interfaces.
- Servers are addressed by stable internal IPs
- These IPs are used by automation (SSH, deployment, benchmarking)
- Servers are not exposed to VPN clients
- DNS is intentionally avoided for server identity

Servers define where execution happens.

## Nodes

```yaml
nodes:
  - laptop
  - phone
```
Nodes represent logical VPN clients.
- Nodes are identities, not devices
- They do not encode OS, hardware, or configuration
- Node‑to‑profile assignment is handled elsewhere

## Interfaces

```yaml
interfaces:
  wg0:
    server: router
    endpoint:
      host: vpn.example.invalid
      port: 51820
```

An interface represents a WireGuard server instance.
Interfaces define:
- Which server runs the interface
- How clients reach it (endpoint)
- Which LAN subnets are reachable
- Which VPN address pools exist
- Whether Internet routing is supported
- Whether IPv6 is supported

Interfaces do not define:
- Client routes
- AllowedIPs
- Firewall behavior

## Profiles

```yaml
profiles:
  profile-split:
    lan: true
    internet: false
```
A profile expresses access policy.

Profiles define intent only:
- Whether LAN access is allowed
- Whether Internet access is allowed
Profiles do not encode routes, CIDRs, or OS behavior.

## Constraints

```yaml
constraints:
  - iface: wg0
    allow_profiles:
      - profile-split
```

Constraints bind profiles to interfaces.
They express which policies are valid on which interfaces.
Constraints are validated by compilers and enforced by renderers.


## Derived State

The following are derived, not declared:
- WireGuard AllowedIPs
- Client and server routing tables
- OS‑specific configuration differences
- IPv4 vs IPv6 handling
- Benchmarking parameters

Derived state is computed by:
- wg-compile-*.sh scripts
- Renderer logic
- OS‑specific templates

Design Principles
- Intent is stable; implementation evolves
- Policy is declarative; mechanics are derived
- Domain files never encode OS quirks
- Servers are addressed by IP; endpoints by name
- Example files document schema, not topology

## Summary
The domain model defines what the VPN should mean.
Everything else defines how that meaning is realized.

This file anchors all the decisions made so far and explains *why* certain things are intentionally absent.
See `docs/allowedips-derivation.md`, for the logic already living in the `.sh` scripts.