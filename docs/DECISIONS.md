# Architecture & Design Decision Log (`ADRs`)

Record every significant technical, structural, or gameplay tradeoff here. Once accepted, never silently rewrite history—add a new ADR that supersedes an earlier one.

---

## ADR Template

```markdown
## ADR-NNN: Short Title
- **Status:** Proposed | Accepted | Superseded by ADR-XXX
- **Date:** YYYY-MM-DD
- **Context:** What problem or constraint prompted this decision?
- **Decision:** What was chosen?
- **Consequences:** Tradeoffs, follow-up requirements, and affected files.
```

---

## ADR-001: Split Source of Truth Between Rojo (`src/`) and Roblox Studio MCP
- **Status:** Accepted
- **Date:** 2026-11-19
- **Context:** Roblox games mix Luau source code (which benefits from Git, branching, and code review) with 3D spatial geometry, lighting, audio, and animations authored inside Roblox Studio.
- **Decision:** Rojo (`src/` via `default.project.json`) owns 100% of Luau scripts. Roblox Studio (manipulated interactively or via `Roblox_Studio` MCP) owns modular 3D assets, lighting, sound instances, and animations. All synced containers preserve `"$ignoreUnknownInstances": true`.
- **Consequences:** No gameplay scripts are authored directly in Studio without backing `.luau` files in `src/`. Spatial object tags/attributes must be documented in [ARCHITECTURE.md](./ARCHITECTURE.md).

## ADR-002: Drive Studio Geometry, AI Graph, Safe Room Blueprint & Node Spawns from Shared `MapLayout.luau`
- **Status:** Accepted
- **Date:** 2026-11-19
- **Context:** Hand-placing maze geometry in Studio independently from AI waypoints and Safe Room wall maps leads to desynced pathfinding, unreachable nodes, and misleading blueprints.
- **Decision:** Define the single-floor vent grid once in `src/shared/MapLayout.luau`, and use it as the 1:1 truth for Studio MCP modular prefab placement, server Tile-Graph AI adjacency, Safe Room blueprint rendering, and randomized repair node placement.
- **Consequences:** Map iteration stays fast and deterministic; topology edits happen in `MapLayout.luau` and re-sync cleanly into Studio.

## ADR-003: Use Explicit Vent Tile Adjacency Graph Instead of `PathfindingService` for Entity AI
- **Status:** Accepted
- **Date:** 2026-11-19
- **Context:** Roblox's built-in `PathfindingService` voxelizes navmeshes that routinely fail, clip, or stall inside tight `4.5`-stud ventilation ducts with `0.5`-stud walls.
- **Decision:** Navigate the roaming entity across an explicit **Vent Tile Adjacency Graph** (BFS/A* over grid cells from `MapLayout.luau`), interpolating smoothly along tile centerlines and junction curves.
- **Consequences:** Zero navmesh stalls in narrow tunnels and instant topological awareness (e.g., cutting off player loops or patrolling active fault sectors). Requires entity geometry/collider to stay within the `Entity` `CollisionGroup`.

## ADR-004: Design Around Modular `EntityProfile` Schemas from Day 1
- **Status:** Accepted
- **Date:** 2026-11-19
- **Context:** MVP v0.1 needs to validate crawl feel, co-op loops, and stealth tension quickly, while long-term vision (*Demonology* / *Phasmophobia* inspiration) calls for multiple creepypasta-inspired entities and infestation deduction.
- **Decision:** Parameterize entity vision ranges, noise sensitivity, mimicry flags, movement cadence, and audio/evidence tells in a shared `EntityProfile` data schema from Day 1 rather than hardcoding monster logic.
- **Consequences:** Adding new entities and the v0.2 "Suspected Infestation" deduction checklist requires authoring new profile configs and tell modules rather than rewriting `EntityService` or `RoundService`.

## ADR-005: 1–4 Co-op Work Order Sign-Off Loop with Partial vs. Full XP Payout
- **Status:** Accepted
- **Date:** 2026-11-19
- **Context:** A pure binary "fix all or lose everything" loop causes frustrating wipes in tight co-op vents, whereas instant victory on the final node removes extraction tension.
- **Decision:** Adopt a *Demonology* / *Phasmophobia* extraction contract: players must crawl back out to the Safe Room and **Lock / Sign Off the Work Order**. Incomplete jobs grant partial XP per completed fault; 100% completion awards full contract payout + completion bonus.
- **Consequences:** Supports emergent Safe Room Operator ("man in the chair") play, tense extraction retreats after deep repairs, and tactical risk-reward retreats when teammates go down.
