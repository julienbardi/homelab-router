# docs/glossary.md

# Glossary

This document defines the precise meaning of terms used throughout this
repository. These definitions are normative.

If a term is used inconsistently with this glossary, it is a bug.

---

# Control Plane

The declarative layer that defines intent and topology.

Includes:
- domain.yaml
- domain.example.yaml
- Documentation under docs/

The control plane never encodes implementation details.

---

# Execution Plane

The layer that realizes control‑plane intent.

Includes:
- Router
- NAS
- Shell scripts
- Makefile orchestration

Execution logic may change without modifying intent.

---

# Data Plane

The layer that carries actual traffic.

Includes:
- WireGuard tunnels
- Encrypted packets
- Routed LAN and Internet flows

The data plane is entirely derived.

---

# Server

A machine capable of running WireGuard interfaces.

Examples:
- router
- nas

Servers are identified by stable internal IP addresses and are never addressed
by DNS.

---

# Interface

A WireGuard server instance.

Examples:
- wg0
- wg1

An interface defines:
- where it runs
- which subnets it can route
- which capabilities it supports

---

# Endpoint

The public address clients use to reach a WireGuard interface.

Endpoints may be dynamic and are typically DNS‑based.

Endpoints are distinct from servers.

---

# Node

A logical VPN client identity.

Nodes do not encode:
- operating system
- hardware
- configuration details

---

# Profile

A declaration of access intent.

Profiles express:
- LAN access
- Internet access

Profiles do not encode routes or OS behavior.

---

# Constraint

A rule binding profiles to interfaces.

Constraints define which combinations are valid.

Invalid combinations are rejected at compile time.

---

# AllowedIPs

A WireGuard configuration field defining routed traffic.

AllowedIPs are derived state and are never declared in the domain model.

---

# Derived State

Configuration generated from intent.

Examples:
- AllowedIPs
- Routing tables
- Firewall rules

Derived state is reproducible and disposable.

---

# Benchmark Interface

A WireGuard interface used exclusively for performance testing.

Benchmark interfaces never route production traffic.

---

# Invariant

A condition that must always hold true.

Violating an invariant aborts execution.

---

# Summary

This glossary exists to preserve shared understanding.

If a term feels ambiguous, it must be clarified here.
