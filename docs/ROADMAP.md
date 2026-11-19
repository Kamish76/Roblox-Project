# Project Roadmap & Milestones

> **Current Phase:** `M5 Complete (v0.1 MVP Vertical Slice)` — Ready for Multi-Client Team Test & `v0.2` Deduction Expansion  
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

### M2 — Modular Vent Kit & Shared `MapLayout.luau` Pipeline *(Complete)*
**Goal:** Build the single-floor maze 1:1 from code to Studio and establish Safe Room spatial awareness.
- [x] Author `src/shared/MapLayout.luau` defining `33` grid tiles, `4` color-coded sectors (`A`–`D`) + `HUB`, `8` repair slots, loop guarantees, BFS pathing, and `DropShaft (0,0)`
- [x] Build the 6 core modular prefabs in Studio (`Straight`, `Corner`, `T-Junction`, `Cross`, `Alcove`, `DropShaft`) + `5` sector-colored `FloorGrate` peepholes & bulkhead landmarks
- [x] Assemble `Workspace.VentMap` in Studio via `Roblox_Studio` MCP directly from `MapLayout.luau` (`33` `VentTile`s, `8` standby `RepairNode`s)
- [x] Build Safe Room staging area (`FloorY = 14`), 1:1 **Wall Blueprint** (`BlueprintGui`), `SectorLED` fault annunciator (`4` lamps), standby Work Order Terminal, and bidirectional `DropToVents` / `ClimbToSafeRoom` stance switching
- **Verification Gate:** Verified live in Studio Playtest (`MapLayout.validate()` pass, tags `33/8/4/1/5`, `SafeY=17.00 -> VentY=5.40 -> SafeY=17.10`, multi-tile corner crawl `deltaZ = 8.99` into Sector A, `0` script errors) and via `screen_capture` (legible 1:1 Wall Blueprint + aligned `SectorLED`s, zero light leaks).

### M3 — 1–4 Co-op Repair Loop & Work Order Sign-Off *(Complete)*
**Goal:** Complete the end-to-end contract loop without the monster yet.
- [x] Implement `RoundService.luau` & `RepairService.luau` (`ProximityPrompt` interruptible progress saving `RepairProgress` + spark `ParticleEmitter` & fault lights)
- [x] Randomize `5/8` balanced active fault nodes each round while lighting up corresponding `SectorLED`s in the Safe Room
- [x] Implement **Work Order Sign-Off** (`SignOffPrompt` + `WorkOrderSignOff` remote + 3D `WorkOrderMonitor` + `SafeRoomUI.luau` HUD) with `Zero`, `Partial` (`50 XP`/node), and `Full` (`+150` bonus XP) payout & `4s` round reset
- [x] Verify repair sync, `InSafeRoom` validation, interruptible hold, and Sign-Off extraction in live Studio Playtest
- **Verification Gate:** Verified live in Studio Playtest (`ActiveFaults = 5`, interruptible `1.8s` hold saved `MidProgress = 0.30` / `Resume Repair`, `WorkOrderSignOff` rejected inside vents, resumed to `1 / 5 REPAIRED`, Partial Sign-Off `+50 XP`, auto-reset to `0 / 5 REPAIRED | XP: 50`, `0` script errors).

### M4 — Tile-Graph Entity AI, Detection & Panic Breathing *(Complete)*
**Goal:** Introduce lethal tension, stealth counterplay, and anti-camping pressure.
- [x] Implement `EntityService.luau` (procedural `JointCracker` rig, offset-safe `MapLayout` BFS `Patrol` / `Investigate` / `Chase` state machine, `KillRadius` elimination)
- [x] Wire two-layer detection: raycast LOS (`11` dark vs `42` `HeadlampOn` sight), plus `NoiseEmitted` (`Crawl` / `Gasp`) and `RepairService` spark noise alerts
- [x] Implement Stale Air / Panic Breathing (`PanicRatio` server loop + `PanicController.luau` HUD bar & pulsing vignette)
- [x] Add diegetic headlamp flicker in `HeadlampController.luau` when entity enters `proximityFlickerRange` (`25` studs)
- **Verification Gate:** Verified live in Studio Playtest (`Patrol` `5.92` studs/s, `PanicDark = 0.117 -> PanicLight = 0.032`, `BeamBrightness = 0.34` flicker within `25` studs, `KillRadius` elimination & Safe Room respawn, `SightState = Chase -> LostLOSState = Investigate`, `0` script errors).

### M5 — Audio Horror Polish & Vertical Slice Playtest
**Goal:** Turn the mechanical loop into oppressive horror.
- [x] Add 3-layer spatial audio: entity tells (`EntityScrape`), active node electrical hum (`FaultHum`), and ambient building creaks (`AmbientCreak` + `HeadlampClick`/`PanicGasp`/`ScareSting`, configured via `GameConfig.Audio` IDs)
- [x] Add entity visual model/rig and jump-scare/elimination handling (`ScareFlash`, Safe Room lockdown banner, `[Tab]` squad spectate, and `SQUAD WIPED (+0 XP)` reset)
- [ ] Run full 2–4 player Studio Team Test session covering Safe Room Operator + Crawlers, partial escape after teammate loss, and full clear *(1-player Studio MCP Playtest verified audio emitters, elimination, lockdown, and squad-wipe reset; 2–4 player Team Test pending manual multi-client run)*
- **Verification Gate:** Zero script errors in `get_console_output`, clean `rojo build`, and Playtest sign-off logged in `.icm/03_verify/`.

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
| `OD-04` | **Locked (`M3`):** `5` active faults out of `8` total nodes per contract (`GameConfig.Repair.ActiveFaultCount = 5`) | Design | **Done** (`M3`) |
