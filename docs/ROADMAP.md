# Project Roadmap & Milestones

> **Current Phase:** `M0 — Foundation & Living Documentation Baseline`  
> **Active Target:** Ship a playable, atmospheric **MVP v0.1** vertical slice, then expand into **v0.2 *Demonology*-style Deduction & Multi-Entity Roster**.

---

## MVP v0.1 Milestones

### M0 — Foundation, Governance & Living Docs *(In Progress)*
- [x] Initialize local Git, Triad ICM scaffold (`.icm/`), Graphify baseline, and Obsidian `Project-Context.md`
- [x] Verify `Roblox_Studio` MCP live connection (`Kamish_76's Place: 11192026_1`) & Rojo `7.7.1` toolchain
- [x] Establish Living Documentation Suite (`docs/README.md`, `GDD.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `ROADMAP.md`)
- [ ] Lock `OD-01` (MVP Entity #1 archetype) & `OD-02` (v0.1 deduction scope) in [GDD.md](./GDD.md)

### M1 — First-Person R6 Crawler & Headlamp Test Box
**Goal:** Nail the physical feel of cramped first-person vent crawling before building a full maze.
- [ ] Configure pitch-black Future/Unified Lighting in Studio test box (`>= 0.5` stud wall thickness)
- [ ] Build `CrawlController.luau`: `LockFirstPerson`, disabled jumping, `WalkSpeed` tuning, slower reverse crawl, and `CameraOffset` crawl height
- [ ] Lower R6 physics hitbox (`HipHeight` / collider check) + verify zero ceiling snagging inside `4.5×4.5` stud test tunnel
- [ ] Override R6 `Animate` script with custom crawl animation
- [ ] Build `HeadlampController.luau` (camera-tracked `SpotLight` attachment with damped lag) + `HeadlampToggled` server replication
- **Verification Gate:** Playtest in Studio Play mode confirming smooth crawl turns, zero wall/ceiling camera clipping, zero light-bleed, and `Crawlers` `CollisionGroup` pass-through.

### M2 — Modular Vent Kit & Shared `MapLayout.luau` Pipeline
**Goal:** Build the single-floor maze 1:1 from code to Studio and establish Safe Room spatial awareness.
- [ ] Author `src/shared/MapLayout.luau` defining grid tiles, 4 color-coded sectors (`A`–`D`), loop guarantees, and `DropShaft` anchor
- [ ] Build the 6 core modular prefabs in Studio (`Straight`, `Corner`, `T-Junction`, `Cross`, `Alcove`, `DropShaft`) + `FloorGrate` peepholes & landmarks
- [ ] Assemble single-floor map in Studio via `Roblox_Studio` MCP directly from `MapLayout.luau`
- [ ] Build Safe Room staging area, static **Wall Blueprint**, and `SectorLED` fault annunciator
- **Verification Gate:** Walk/crawl the entire loop network in Studio; confirm every sector has $\ge 2$ escape routes and blueprint matches actual geometry 1:1.

### M3 — 1–4 Co-op Repair Loop & Work Order Sign-Off
**Goal:** Complete the end-to-end contract loop without the monster yet.
- [ ] Implement `RoundService.luau` & `RepairService.luau` (`ProximityPrompt` interruptible progress checkpoints + sparking VFX)
- [ ] Randomize active fault nodes each round while lighting up corresponding `SectorLED`s in the Safe Room
- [ ] Implement **Work Order Sign-Off** terminal in Safe Room (`Zero`, `Partial`, and `Full` XP/payout calculation + round reset)
- [ ] Verify 1-player and multi-player (Studio multi-client test) co-op repair sync and extraction states
- **Verification Gate:** Complete both a Partial Sign-Off (`e.g. 2/5`) and a Full Sign-Off (`5/5`) cleanly in Studio local server test.

### M4 — Tile-Graph Entity AI, Detection & Panic Breathing
**Goal:** Introduce lethal tension, stealth counterplay, and anti-camping pressure.
- [ ] Implement `EntityProfiles.luau` and `EntityService.luau` (Tile Adjacency Graph BFS/A* patrol + hunt routing)
- [ ] Wire two-layer detection: passive dark vision vs. long-range `HeadlampOn` beam sight, plus crawl/repair audio investigation
- [ ] Implement `PanicController.luau` (Stale Air / Panic Breathing meter rising in stillness/darkness, triggering audible gasps)
- [ ] Add diegetic headlamp flicker when entity enters `proximityFlickerRange`
- **Verification Gate:** Confirm entity patrols smoothly around tight corners, loses aggro when light is cut and player ducks into an `Alcove`/loop, and punishes reckless light/noise.

### M5 — Audio Horror Polish & Vertical Slice Playtest
**Goal:** Turn the mechanical loop into oppressive horror.
- [ ] Add 3-layer spatial audio: entity tells (scrapes/clicks/cracks), active node electrical hum (~1.5 tiles out), and ambient building creaks
- [ ] Add entity visual model/rig and jump-scare/elimination handling (spectate Safe Room or teammates on death)
- [ ] Run full 2–4 player Studio test session covering Safe Room Operator + Crawlers, partial escape after teammate loss, and full clear
- **Verification Gate:** Zero script errors in `get_console_output`, stable FPS, clean playtest sign-off logged in `.icm/03_verify/`.

---

## v0.2 Expansion Backlog (*Demonology* / *Phasmophobia* Escalation)

* **Multi-Entity Roster:** Implement remaining archetypes from [GDD.md](./GDD.md) (*Wall-Squatter / Mimic*, *Clicking Crawler*, *Ceiling-Clinger*, *Inverted Scuttler*).
* **Suspected Infestation Deduction Clipboard:** Add evidence tells & Work Order entity selection checkbox for 2× payout bonus.
* **Safe Room Dispatcher Tools:** Sector pressure sensors / motion pings on the Safe Room blueprint for deeper "man in the chair" teamwork.
* **Tactical Vent Mechanics:** Heavy manual vent dampers (temporary entity block at the cost of a loud metallic *CLANG*), battery/flicker management, and shop gear progression from earned XP/cash.
* **Multi-Map / Multi-Floor Contracts:** Additional building templates driven by `MapLayout` configs.

---

## Open Decisions Gate (Blocks M2 / M4 Finalization)

| ID | Decision Needed | Owner | Target Gate |
| :--- | :--- | :--- | :--- |
| `OD-01` | Pick **MVP Entity #1** archetype (*Joint-Cracker*, *Clicking Crawler*, *Mimic*, *Ceiling-Clinger*, or *Inverted Scuttler*) | User | Before `M4` (ideal: now) |
| `OD-02` | Confirm **v0.1 Deduction Scope** (1 entity in v0.1 -> deduction in v0.2, vs. 2-entity deduction in v0.1) | User | Before `M3`/`M4` |
| `OD-03` | Finalize Grid Footprint (`8×8` vs. `10×10` studs) after R6 crawl test | Engineering | During `M1` |
| `OD-04` | Tune active vs. total repair node count (`e.g. 5/9`) | Design | During `M3` |
