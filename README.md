# Chaossynergy

**The OS is the agent interface.** This time: a server appliance.

This repo builds **Chaossynergy** — the name carries forward from
[dark5un/chaossynergy](https://github.com/dark5un/chaossynergy) (the bootc/Bluefin
prototype, now historical). Like its name suggests it is chaos + synergy; as of
Edition 1 it is **not an atomic OS** — plain Arch with appliance discipline and
snapshot A/B rollback (snapper + Limine); atomicity is a live option for a later
edition, not a present promise. It packages a proven
production server build: an agent-native Arch appliance that
installs **offline**, on **one disk** (Edition 1), and lands a full AI-lab quadlet
stack that stays **dormant** until a post-install app probes the target hardware and
finalizes it — generic GPU slots (`nvidia-gpu-0..N`), fresh per-install secrets, tier
activation by choice.

Three principles carry over verbatim:

1. the substrate is sacred and dumb (appliance, not a workstation),
2. the agent is disposable (container; delete and recreate in seconds),
3. safety by construction, not policy (A/B snapshots + rollback, not discipline).

Method: every machine is built from this repo; a live machine is only ever a
deployment target.

## Status

Planning — [docs/server-edition-plan.md](docs/server-edition-plan.md) (v0.4, merged
from two expert reviews). No code yet; milestones M0-M5 in the plan.

- `docs/adr/` — ADRs 001-012 are the historical v1 record (some describe the
  superseded bootc/Bluefin prototype; they are kept only so numbering continues —
  ADR-013 onward define THIS product). No bootc in the server design.

## Naming

This project is **not** "ryoku": it is derived from and influenced by the ryoku
distro machinery, but no product name, path, unit, or contract here will carry the
ryoku name. Derived installer code stays GPL-3.0; the lab payload stays Apache-2.0 —
the boundary is defined in ADR-013 (pending).
