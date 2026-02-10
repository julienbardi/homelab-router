# Architecture Overview

This document describes the high‑level architecture of the WireGuard system
defined in this repository. It explains the roles of each component and how
control‑plane intent is translated into runtime behavior.

---

## Architectural Goals

The system is designed to:

- Separate intent from implementation
- Support multiple WireGuard servers
- Enable reproducible benchmarking
- Avoid configuration drift
- Remain auditable and deterministic

---

## Planes of Responsibility

The architecture is split into three planes:

- Control Plane
- Execution Plane
- Data Plane

Each plane has a distinct role and boundary.

---

## Control Plane

The control plane defines *what should exist*.

It consists of:

- domain.yaml
- domain.example.yaml
- Documentation in docs/

Responsibilities:

- Declare servers and their identities
- Declare WireGuard interfaces
- Declare reachable subnets
- Declare access profiles
- Declare valid profile‑to‑interface bindings

The control plane is declarative and stable.

It does not encode OS behavior, routing mechanics, or performance tuning.

---

## Execution Plane

The execution plane realizes intent.

It consists of:

- Router
- NAS
- Shell scripts
- Renderers

Responsibilities:

- Compile domain intent into concrete configuration
- Generate keys and allocations
- Emit WireGuard configs
- Apply firewall and routing rules
- Start and manage WireGuard interfaces

Execution logic may change without modifying the domain model.

---

## Data Plane

The data plane carries traffic.

It consists of:

- WireGuard tunnels
- Encrypted packets
- Routed LAN and Internet traffic

The data plane is entirely derived from execution‑plane output.

---

## Router Role

The router:

- Runs production WireGuard interfaces
- Terminates VPN tunnels
- Routes LAN and Internet traffic
- Enforces firewall and NAT rules
- Mounts the NAS to read domain intent

The router is stateless with respect to intent.

---

## NAS Role

The NAS:

- Stores domain.yaml
- Stores generated artifacts
- Hosts benchmark WireGuard servers (wg1…wg15)
- Provides stable storage and backups

The NAS is authoritative for intent but does not route production traffic.

---

## Multi‑Server Design

Multiple WireGuard servers exist simultaneously:

- wg0 on the router
- wg1…wg15 on the NAS

This enables:

- Performance benchmarking
- Kernel vs user‑space comparison
- Isolation of experimental interfaces
- Controlled evaluation without impacting production VPN

---

## Identity and Addressing

- Servers are identified by stable internal IPs
- Automation communicates with servers via IP
- VPN clients connect via dynamic endpoints (DNS)
- Server identity and endpoint identity are distinct concepts

---

## Derived State

The following are derived at runtime:

- AllowedIPs
- Routing tables
- Firewall rules
- OS‑specific configuration
- Benchmark parameters

Derived state is not stored in the domain model.

---

## Failure and Recovery Model

- Domain intent survives router replacement
- Router can be rebuilt from NAS‑hosted intent
- Benchmark servers can be added or removed without schema changes
- No single device holds exclusive configuration authority

---

## Summary

The architecture enforces strict separation:

- Domain files define meaning
- Scripts define realization
- Devices execute behavior

This separation enables clarity, safety, and long‑term maintainability.
