# Documentation Hub — `roblox-project`

Welcome to the living documentation suite for our 1–4 player co-op claustrophobic vent-crawling horror game in Roblox. Every document in `docs/` serves as a **single source of truth** for its domain and must be updated alongside any code (`src/`) or Roblox Studio change.

---

## Document Index

| Document | Domain | Purpose |
| :--- | :--- | :--- |
| [README.md](./README.md) | Governance | Docs hub, Source-of-Truth ownership boundaries, and the Living Docs Sync Checklist |
| [GDD.md](./GDD.md) | Game Design | Core pillars, 1–4 co-op loop, Work Order partial/full XP rules, claustrophobia mechanics, modular kit specs, Entity Bank, open questions |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Engineering | Rojo/Studio split, module boundaries, `MapLayout.luau` 1:1 pipeline, Contracts Registry (`Remotes`, `Tags`, `Attributes`, `CollisionGroups`), Roblox guardrails |
| [DECISIONS.md](./DECISIONS.md) | Architecture Log | Numbered ADRs (`ADR-001+`) capturing *why* technical and design tradeoffs were chosen |
| [ROADMAP.md](./ROADMAP.md) | Delivery Plan | Phased MVP v0.1 milestones (`M0`–`M5`), v0.2 *Demonology*-style deduction backlog, and playtest verification checklists |

---

## Source-of-Truth Boundaries

| Surface | Owns | Must Never Own | Sync Mechanism |
| :--- | :--- | :--- | :--- |
| **Rojo (`src/`)** | All Luau scripts, shared configs (`MapLayout.luau`, `EntityProfile`), remote wrappers, gameplay & AI logic | Binary 3D models, audio asset files, lighting props | Git + `rojo serve` (with `$ignoreUnknownInstances: true`) |
| **Roblox Studio (`Roblox_Studio` MCP)** | Modular 3D vent kit meshes/parts, Safe Room build, `Lighting`, `Sound` instances, R6 `Animation` assets | Unversioned inline gameplay scripts outside Rojo | Studio MCP + cloud place save (`Kamish_76's Place: 11192026_1`, Place ID `119329366233303`) |
| **`docs/` (This Directory)** | Living design rules, Studio/network contracts, technical invariants, ADRs, milestone checklists | Duplicated copy-pasted Luau code | Updated in the same feature branch/PR as code or Studio changes |
| **Obsidian DevBrain** | Cross-session project memory (`01_Projects/roblox-project/Project-Context.md`) & vault index (`00_Vault_Index.md`) | Granular per-file implementation specs | Synced during project setup and `/wrapup` |

---

## Living Docs Sync Checklist

Whenever you complete a task or feature branch, check every matching trigger below and update the required document(s) **before committing**:

| If Your Change Adds or Modifies… | Update These Docs |
| :--- | :--- |
| A `RemoteEvent` / `RemoteFunction` or payload contract | [ARCHITECTURE.md](./ARCHITECTURE.md) (*Contracts Registry → Remotes*) |
| A `CollectionService` tag, Instance `Attribute`, or `CollisionGroup` | [ARCHITECTURE.md](./ARCHITECTURE.md) (*Contracts Registry*) |
| A new Luau module or Rojo `default.project.json` mapping | [ARCHITECTURE.md](./ARCHITECTURE.md) (*Module Topology*) + re-run `graphify` if needed |
| Player controls, Work Order XP math, claustrophobia meters, or modular vent dimensions | [GDD.md](./GDD.md) |
| An entity archetype, `EntityProfile` field, or AI detection rule | [GDD.md](./GDD.md) (*Entity Reference Bank*) + [ARCHITECTURE.md](./ARCHITECTURE.md) |
| A significant technical or design tradeoff (or reverses a prior choice) | [DECISIONS.md](./DECISIONS.md) (add/supersede `ADR-NNN`) |
| A milestone deliverable or resolves an open design question | [ROADMAP.md](./ROADMAP.md) + [GDD.md](./GDD.md) |
| Major project state, stack additions, or architectural milestones | Obsidian `01_Projects/roblox-project/Project-Context.md` (via `/wrapup`) |

---

## ICM Workflow Integration
Per [GEMINI.md](../GEMINI.md) and [.icm/CONTEXT.md](../.icm/CONTEXT.md):
1. Reference `docs/ARCHITECTURE.md` and `docs/GDD.md` during **Stage 1 (`01_spec`)** before proposing changes.
2. Include documentation updates explicitly in **Stage 2 (`02_plan`)**.
3. Verify all impacted docs match the implemented code/Studio state during **Stage 3 (`03_verify`)** prior to committing.
