# Benchmarking Architecture and Intent

This document explains how benchmarking fits into the overall WireGuard
architecture and why it is modeled the way it is.

Benchmarking is a first‑class use case of this system, but it is intentionally
kept out of the domain model.

---

## Purpose of Benchmarking

Benchmarking is used to:

- Compare WireGuard performance across hosts
- Compare kernel vs user‑space implementations
- Measure throughput, latency, and CPU impact
- Validate routing and encryption behavior under load
- Detect regressions over time

Benchmarking must not affect production VPN behavior.

---

## Benchmark Targets

Benchmarking is performed using multiple WireGuard servers:

- wg0 on the router (production reference)
- wg1…wg15 on the NAS (benchmark targets)

Each interface is independent and isolated.

---

## Why Benchmarking Is Not in the Domain Model

Benchmarking is excluded from the domain model because:

- It is an operational concern, not topology
- It changes frequently
- It depends on tooling and methodology
- It must not influence access policy
- Encoding it would pollute intent with experimentation

The domain model defines *what exists*.
Benchmarking defines *how it is evaluated*.

---

## Benchmark Control Flow

Typical benchmark flow:

1. Select a WireGuard interface (wg1…wg15)
2. Deploy configuration to the target server
3. Generate client configuration
4. Establish tunnel
5. Run traffic generation tools
6. Collect metrics
7. Tear down or reset state

All steps are driven by scripts, not domain data.

---

## Isolation Guarantees

Benchmark interfaces are isolated by design:

- Separate WireGuard interfaces
- Separate ports
- Separate VPN subnets
- No Internet routing
- No production traffic

This ensures benchmarks do not interfere with real users.

---

## Metrics and Tooling

Benchmarking may involve:

- iperf / iperf3
- ping / fping
- CPU and memory sampling
- Interface counters
- Kernel statistics

Tool choice is intentionally left outside the domain model.

---

## Reproducibility

Reproducibility is achieved by:

- Declarative interface definitions
- Deterministic key generation
- Stable server identities
- Scripted deployment
- Explicit teardown

Benchmark results can be compared across time and hosts.

---

## Summary

- Benchmarking is intentional but external
- Multiple WireGuard servers enable comparison
- Domain intent remains clean and stable
- Scripts control execution and measurement
- Production VPN behavior is never affected
