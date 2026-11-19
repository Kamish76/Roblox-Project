# Project Roadmap & Milestones

> **Current Phase:** `M2 — Modular Vent Kit & Shared MapLayout.luau Pipeline` (`M1` Complete!)  
> **Active Target:** Ship a playable, atmospheric **MVP v0.1** vertical slice, then expand into **v0.2 *Demonology*-style Deduction & Multi-Entity Roster**.

---

## MVP v0.1 Milestones

### M0 — Foundation, Governance & Living Docs *(Complete)*
- [x] Initialize local Git, Triad ICM scaffold (`.icm/`), Graphify baseline, and Obsidian `Project-Context.md`
- [x] Verify `Roblox_Studio` MCP live connection (`Kamish_76's Place: 11192026_1`) & Rojo `7.7.1` toolchain
- [x] Establish Living Documentation Suite (`docs/README.md`, `GDD.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `ROADMAP.md`)
- [x] Lock `OD-01` (MVP Entity #1 archetype) & `OD-02` (v0.1 deduction scope) in [GDD.md](./GDD.md)

### M1 — First-Person R6 Crawler & Headlamp Test Box *(Complete)*
**Goal:** Nail the physical feel of cramped first-person vent crawling before building a full maze.
- [x] Configure pitch-black Unified Lighting (`LightingStyle = Realistic`, `PrioritizeLightingQuality = true`) in Studio `M1_TestVentBox` (`0.6` stud walls + `1.7` stud solid corners)
- [x] Build `CrawlController.luau`: `LockFirstPerson`, disabled jumping, forward/strafe/reverse `WalkSpeed` (`5.5` / `4.2` / `3.4`), and `CameraOffset` (`-1.20Y`) prone eye height
- [x] Lower R6 physics hitbox (`HipHeight = -1.6`, non-root limbs `CanCollide = false`, `StarterPlayer.StarterCharacter` R6 rig) + verify zero ceiling snagging inside `4.6×4.2` stud test loop
- [x] Override R6 `Animate` script (`src/character/Animate.client.luau`) + procedural Motor6D crawl poses in `CrawlController.luau`
- [x] Build `HeadlampController.luau` (`Workspace._LocalClientVFX.LocalHeadlampRig`) + `HeadlampToggled` server replication + co-op teammate beams
- **Verification Gate:** Verified live in Studio Play mode (`RigType = R6`, `HipHeight = -1.60`, `CamY = 5.84` vs `HeadY = 5.68`, `deltaZ = 8.88` studs in `1.6s`, `RootJoint.Transform` active, `HeadlampToggled` server round-trip OK, `0` script errors, Edit `screen_capture` zero light bleed).

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
| `OD-01` | **Locked:** **The Joint-Cracker** chosen as MVP Entity #1 (`ADR-006`) | User | **Done** |
| `OD-02` | **Locked:** **1 entity in v0.1** (`Joint-Cracker`), *Demonology* multi-entity deduction in **v0.2** (`ClickingCrawler` queued as #2, `ADR-006`) | User | **Done** |
| `OD-03` | **Validated (`M1`):** `8×8` stud cell footprint (`4.6×4.2` stud interior duct, `0.6+` stud walls) verified snag-free in M1 Playtest | Engineering | **Done** (`M1`) |
| `OD-04` | Tune active vs. total repair node count (`e.g. 5/9`) | Design | During `M3` |
