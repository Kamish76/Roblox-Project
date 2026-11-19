# Living Game Design Document (`GDD`)

> **Status:** Pre-Production Baseline (MVP v0.1 Scoping)  
> **Genre:** 1–4 Player Co-op Claustrophobic Survival Horror  
> **Engine:** Roblox Studio (`Future` / Unified Lighting, R6 Rig)  
> **Inspirations:** *Slender* (objective hunting), *Crawlspace VR* (cramped reactive tension), Roblox *Demonology* & *Phasmophobia* (co-op push-your-luck contracts & entity deduction)

---

## 1. High-Concept Pitch & Design Pillars

You and up to three coworkers are overnight HVAC/ventilation technicians crawling through the pitch-black, single-floor ductwork of a compromised building to fix failing system nodes—while something inspired by tight-space urban legends stalks the shafts with you.

### Three Non-Negotiable Pillars
1. **Claustrophobia Is the Core Mechanic:** Tight metal tunnels (`4.5` studs wide) dictate everything—slow movement, slower reverse crawl, single-file squad bottlenecks, stale air panic breathing, and nowhere to simply sprint away.
2. **Push-Your-Luck Co-op Contracts (*Demonology* / *Phasmophobia* Loop):** Players choose when to push deeper or cut losses. Extracting to the Safe Room and locking an incomplete Work Order pays partial XP per completed fault; completing all faults yields full payout and bonus.
3. **Sensory Counterplay Over Combat:** No weapons. Survival relies on headlamp discipline, spatial audio cues, reading the Safe Room blueprint/sector LEDs, tucking into recessed alcoves, and slipping past threats around loop corridors.

---

## 2. Core Gameplay Loop (1–4 Player Co-op)

```
[1. Safe Room Briefing] ──▶ [2. Crawl & Repair Faults] ──▶ [3. Evade & Survive]
         ▲                                                           │
         └────────── [4. Extract & Sign Off Work Order] ◀────────────┘
```

### Phase 1: Safe Room Briefing & Co-op Role Split
* **Safe Room (Top Floor):** Well-lit staging area above the ceiling grid featuring:
  * **Static Wall Blueprint:** Complete visual layout of the single-floor vent grid divided into 4 color-coded sectors (`A`–`D`).
  * **Sector Fault Annunciator:** Blinking fault LEDs showing *which sectors* contain active broken nodes this round (guiding route planning without pinpointing exact tiles).
  * **Work Order Clipboard / Terminal:** Displays active fault count, completed count, and the **Lock & Sign Off** extraction lever.
* **Emergent Co-op Roles:**
  * **Crawlers (1–4 players):** Drop through the `DropShaft` hatch into pitch-black ducts with a headlamp to locate and repair active faults.
  * **Safe Room Operator ("Man in the Chair", optional):** One teammate can stay upstairs monitoring the Wall Blueprint + Sector Vibration/Proximity LEDs to call out warnings and guide crawlers over chat/voice—trading extra hands downstairs for eyes upstairs.

### Phase 2: Crawling & Interruptible Repairs
* **Randomized Fault Spawning:** Each round activates $N$ fault nodes across the static maze (placed at junctions or recessed alcoves, never deep un-looped dead ends).
* **Interruptible `ProximityPrompt` Repairs:** Holding to repair emits localized electrical sparks and noise. Progress saves at checkpoints (or persists partially) so a player who hears approaching scrapes can abort, kill their headlamp, slip into a loop/alcove, and return later to finish.
* **Single-File Squad Tension:** Tight ducts force single-file movement. Point-man spots eyes ahead and calls *"BACK UP!"* while trailing teammates scramble to reverse into the nearest side branch. *(Server assigns player `CollisionGroup` rules to prevent griefing/hard wedging while preserving cramped visual proximity.)*

### Phase 3: Stealth & Claustrophobia Mechanics
* **Two-Layer Entity Detection:**
  * **Vision:** Tight passive dark awareness (~10–12 studs); expands sharply along line-of-sight (~35–45 studs) when a player's headlamp is ON.
  * **Audio:** Entity investigates crawling vibrations and loud sparking repair audio—letting players survive close passes by freezing in the dark.
* **Stale Air / Panic Breathing:** Remaining motionless in pitch darkness with your headlamp OFF keeps you hidden visually, *but* gradually builds a **Panic / Stale Air** meter. At high panic, audible gasping/hyperventilation triggers and risks drawing the entity—preventing infinite AFK corner camping.
* **Slow Reverse Crawl:** Crawling backward is intentionally slower than crawling forward, punishing blind deep pushes down unverified corridors.
* **Diegetic Proximity Tells:** When the entity closes within ~25 studs, player headlamps experience subtle flickering and electrical hum (minimal/no HUD clutter).

### Phase 4: Extraction & Work Order Sign-Off (Win / Payout Rules)
To end a contract, at least one surviving player must crawl back up the `DropShaft` into the Safe Room and **Lock & Sign Off the Work Order**:

| Sign-Off State | Condition | Outcome & Reward Rule |
| :--- | :--- | :--- |
| **Partial Sign-Off** | Job locked with $1 \le \text{Repaired} < \text{Required}$ | Contract ends safely for survivors; awards **partial XP/payout** scaled per repaired node (no completion bonus). Ideal when teammates fall or threat escalation peaks. |
| **Full Sign-Off** | Job locked with $\text{Repaired} = \text{Required}$ | Full contract completion payout + **Full-Clear Bonus XP**. |
| **Zero-Progress Abort** | Job locked with $0$ nodes repaired | Safe extraction, $0$ contract XP. |
| **Total Squad Wipe** | All players eliminated inside vents | Contract failed; minimal/zero payout. |
| *(v0.2 Escalator)* **Entity Deduction Bonus** | Correctly check *"Suspected Infestation"* on Work Order | Multiplies base payout (core *Demonology* hook, enabled once multi-entity roster ships). |

---

## 3. Map Design & Modular Vent Kit Specification

All single-floor maps follow strict dimensional and topological standards so R6 characters, Future/Unified shadows, and Tile-Graph AI never desync.

### Dimensional Standards
* **Grid Cell Footprint:** `8×8` studs *(or `10×10` studs — see Open Questions)* per modular tile.
* **Interior Tunnel Clearance:** `4.5–5` studs wide × `4–4.5` studs tall.
* **Wall / Ceiling / Floor Thickness:** `>= 0.5` studs minimum to prevent Future/Unified shadow light-bleed.

### The 6 Core Modular Prefabs
1. `Straight` — Linear duct shaft (`I`-piece).
2. `Corner` — $90^\circ$ elbow (`L`-piece).
3. `T-Junction` — 3-way branch (`T`-piece).
4. `Cross` — 4-way intersection (`+`-piece).
5. `Alcove` — Recessed service pocket / repair bay allowing a player to tuck aside from the main axis.
6. `DropShaft` — Vertical entry/exit shaft connecting the Safe Room hatch down into the vent floor.

### Navigation Landmarks & Anti-Checkmate Topology
* **4 Color-Coded Sectors:**
  * **Sector A (Red):** Boiler Ducts
  * **Sector B (Blue):** Coolant Line
  * **Sector C (Amber):** Main Exhaust
  * **Sector D (Green):** Power Conduit
* **Visual & Audio Landmarks:** Stenciled sector lettering/stripes, flickering emergency lights, frayed sparking wire decals, and **Floor Grate Peepholes** looking down into dimly lit building silhouettes below (casting faint colored spill upward into the duct).
* **Loop-First Guarantee:** All primary corridors must connect into closed loops ($\ge 2$ escape routes). Repair nodes never spawn at the tip of long un-looped dead ends.

---

## 4. Creepypasta Entity Reference Bank & `EntityProfile` Schema

Online tight-space and crawlspace horror legends inform our creature roster. All entities share one modular `EntityProfile` architecture so MVP v0.1 ships fast and scales cleanly into *Demonology*-style deduction in v0.2.

### Reference Archetypes

| Archetype & Online Inspiration | Visual & Audio Vibe | Stealth Counterplay |
| :--- | :--- | :--- |
| **1. The Joint-Cracker** *(Creepypasta "The Crawlspace", The Rake, SCP-096)* | Gaunt, pale, over-elongated limbs folded unnaturally on all fours; faint yellow eye-shine down long ducts; wet **joint-cracking** + raspy whispers (*"turn it off…"*). | **Light-Reactive:** Detects headlamp beams at long range down straight ducts. Kill light, tuck into an alcove, avoid shining directly at it. |
| **2. The Wall-Squatter / Mimic** *(r/nosleep "Phrogging" / wall-dwellers, Mandela Catalogue, Skinwalkers)* | Grimy hunched silhouette resembling a lost technician from behind; **mimics teammate cues** (fake wrench clanks, headlamp clicks, muffled distress calls from wrong shafts). | **Co-op Comms & Verification:** Punishes split teams. Cross-check teammate positions via Safe Room blueprint before moving toward sounds. |
| **3. The Clicking Crawler** *(SCP-4975 "Time's Up", Alien airshafts, A Quiet Place)* | Blind, gaunt metallic/chitinous crawler; rhythmic **clicking/tapping** echoing through sheet metal that speeds up on lock-on—then cuts dead silent before lunging. | **Vibration-Reactive:** Weak eyesight, hyper-sensitive to crawling noise and sparking repairs. Freeze immediately when clicking accelerates. |
| **4. The Ceiling-Clinger / The Squeeze** *(Ted the Caver, Enigma of Amigara Fault, Lethal Company Snare Flea)* | Contorted dark silhouette wedged flat against **upper duct ribs**; rust/dust falls into headlamp beams + flexing metal groans overhead. | **Spatial Caution:** Inspect intersections and duct ceilings before pushing through; take alternate loop routes around ambushes. |
| **5. The Inverted Scuttler** *(Crawlspace VR, The Grudge attic, Backrooms vent entities)* | Head-tilted uncanny crawler skittering rapidly down straightaways, freezing abruptly when caught in direct headlamp light. | **Line-of-Sight Chicken:** Brief freeze/flinch on light contact gives a window to duck sideways—staring too long triggers a charge. |

### Modular `EntityProfile` Contract (Luau Table Shape)
Every entity reads from a shared profile structure in `src/shared/`:
```luau
export type EntityProfile = {
	id: string,
	displayName: string,
	passiveVisionRange: number,    -- studs in pitch dark
	lightAggroRange: number,       -- studs when target headlamp is ON
	noiseSensitivity: number,      -- multiplier for crawl/repair noise radius
	mimicEnabled: boolean,         -- can emit fake player/repair audio cues
	patrolCadence: number,         -- tiles/sec base patrol speed
	chaseCadence: number,          -- tiles/sec alert/chase speed
	proximityFlickerRange: number, -- studs where player headlamps flicker
	audioTells: { string },        -- Sound IDs / cue keys for patrol, stalk, lunge
	deductionClues: { string },    -- v0.2 Demonology evidence tags
}
```

---

## 5. Open Design Questions

| ID | Question | Options Under Consideration | Status |
| :--- | :--- | :--- | :--- |
| `OD-01` | **MVP Entity #1 Selection** | **The Joint-Cracker** (*"The Crawlspace"* / *The Rake* archetype — faint yellow eye-shine, wet joint-cracking & whispers, light-reactive headlamp aggro + noise investigation) | **Locked** (`ADR-006`) |
| `OD-02` | **v0.1 Deduction Scope** | **MVP v0.1 ships with 1 Entity (`Joint-Cracker`)** driven by modular `EntityProfile` (`src/shared/EntityProfiles.luau`); **v0.2** unlocks *Demonology*-style multi-entity deduction starting with **The Clicking Crawler** as Entity #2 | **Locked** (`ADR-006`) |
| `OD-03` | **Grid Cell Footprint** | **`8×8` studs** (`4.6×4.2` stud interior clearance, `0.6+` stud walls) verified snag-free in M1 R6 Playtest | **Validated (`M1`)** |
| `OD-04` | **Active Repairs Per Contract** | **`5` active faults out of `8` total nodes** per contract (`GameConfig.Repair.ActiveFaultCount = 5`, balanced across sectors) | **Locked (`M3`)** |
