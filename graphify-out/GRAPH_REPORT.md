# Graph Report - roblox-project  (2026-11-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 120 nodes · 237 edges · 11 communities (9 shown, 2 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 22 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ca7e61b9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8

## God Nodes (most connected - your core abstractions)
1. `EntityService.init()` - 12 edges
2. `updateNodeVisuals()` - 9 edges
3. `NetContracts.getRemoteEvent()` - 9 edges
4. `broadcastState()` - 8 edges
5. `RoundService.init()` - 8 edges
6. `RoundService.startNewRound()` - 8 edges
7. `updateDetectionAndElimination()` - 7 edges
8. `SafeRoomUI.init()` - 7 edges
9. `EntityService.alertNoise()` - 6 edges
10. `EntityService.worldToTileKey()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `EntityService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/EntityService.luau → src/shared/NetContracts.luau
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.worldToTile()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `pickBalancedFaultIds()` --calls--> `MapLayout.getRepairSlots()`  [INFERRED]
  src/server/RoundService.luau → src/shared/MapLayout.luau
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau

## Import Cycles
- None detected.

## Communities (11 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.15
Nodes (23): computeMapOffset(), createEntityRig(), EntityService.alertNoise(), EntityService.init(), EntityService.teleportToTile(), EntityService.tileKeyToWorld(), EntityService.worldToTileKey(), hasLineOfSight() (+15 more)

### Community 1 - "Community 1"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 2 - "Community 2"
Cohesion: 0.30
Nodes (14): RepairService.getActiveFaultSectors(), RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.checkSquadWipe(), RoundService.getState() (+6 more)

### Community 3 - "Community 3"
Cohesion: 0.31
Nodes (10): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.init(), RepairService.setNodeProgress() (+2 more)

### Community 4 - "Community 4"
Cohesion: 0.24
Nodes (3): createHud(), PanicController.init(), updateVisuals()

### Community 5 - "Community 5"
Cohesion: 0.42
Nodes (7): AudioController.init(), AudioController.playScareSting(), createSound(), ensureEntityAudio(), ensureFaultHum(), NetContracts.getOrCreateRemotesFolder(), NetContracts.getRemoteEvent()

### Community 6 - "Community 6"
Cohesion: 0.53
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 7 - "Community 7"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 8 - "Community 8"
Cohesion: 0.46
Nodes (7): applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera(), SafeRoomUI.init(), triggerScareFlash()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 5` to `Community 0`, `Community 1`, `Community 2`, `Community 4`, `Community 7`, `Community 8`?**
  _High betweenness centrality (0.122) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `NetContracts.getRemoteEvent()` (e.g. with `AudioController.init()` and `HeadlampController.init()`) actually correct?**
  _`NetContracts.getRemoteEvent()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Why does `EntityService.init()` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `RoundService.init()` connect `Community 2` to `Community 3`, `Community 5`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._