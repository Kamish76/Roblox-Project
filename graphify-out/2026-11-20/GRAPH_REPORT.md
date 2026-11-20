# Graph Report - roblox-project  (2026-11-20)

## Corpus Check
- 19 files · ~25,864 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 5 file(s) not represented in the graph (top: (none) 2, .blend 1, .fbx 1)

## Summary
- 142 nodes · 283 edges · 14 communities (12 shown, 2 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5de4dfe7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PlayerStateService.luau
- RoundService.luau
- RepairService.luau
- EntityService.luau
- MapLayout.luau
- CrawlController.luau
- EntityAnimator.luau
- NetContracts.getRemoteEvent
- HeadlampController.luau
- SafeRoomUI.luau
- updateDetectionAndElimination
- pickRetreatTile

## God Nodes (most connected - your core abstractions)
1. `updateDetectionAndElimination()` - 13 edges
2. `updateNodeVisuals()` - 9 edges
3. `pickCorridorPeekCorner()` - 8 edges
4. `broadcastState()` - 8 edges
5. `RoundService.init()` - 8 edges
6. `RoundService.startNewRound()` - 8 edges
7. `MapLayout.getTileByKey()` - 8 edges
8. `NetContracts.getRemoteEvent()` - 8 edges
9. `setState()` - 7 edges
10. `pickRetreatTile()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.getTileByKey()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.worldToTile()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `setDestination()` --calls--> `MapLayout.findPath()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `isSameCorridorAxis()` --calls--> `MapLayout.getTileByKey()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau

## Import Cycles
- None detected.

## Communities (14 total, 2 thin omitted)

### Community 0 - "PlayerStateService.luau"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.30
Nodes (14): RepairService.getActiveFaultSectors(), RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.checkSquadWipe(), RoundService.getState() (+6 more)

### Community 2 - "RepairService.luau"
Cohesion: 0.27
Nodes (10): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.init(), RepairService.setNodeProgress() (+2 more)

### Community 3 - "EntityService.luau"
Cohesion: 0.24
Nodes (3): hasLineOfSight(), hasLineOfSightFrom(), isPlayerLookingAtEntity()

### Community 4 - "MapLayout.luau"
Cohesion: 0.24
Nodes (9): EntityService.worldToTileKey(), pickPatrolDestination(), MapLayout.findPath(), MapLayout.getNeighbors(), MapLayout.getRepairSlots(), MapLayout.getTile(), MapLayout.key(), MapLayout.tileToWorld() (+1 more)

### Community 5 - "CrawlController.luau"
Cohesion: 0.38
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 6 - "EntityAnimator.luau"
Cohesion: 0.43
Nodes (7): applyCrawlLimbs(), bindEntityModel(), composeBone(), findAndBindEntity(), rotAround(), setTarget(), updateAnimation()

### Community 7 - "NetContracts.getRemoteEvent"
Cohesion: 0.27
Nodes (10): AudioController.init(), AudioController.playScareSting(), createSound(), ensureEntityAudio(), ensureFaultHum(), createHud(), PanicController.init(), updateVisuals() (+2 more)

### Community 8 - "HeadlampController.luau"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 9 - "SafeRoomUI.luau"
Cohesion: 0.21
Nodes (7): applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera(), SafeRoomUI.init(), triggerScareFlash()

### Community 10 - "updateDetectionAndElimination"
Cohesion: 0.33
Nodes (11): enterChase(), enterLurk(), enterRetreat(), enterScrambleToCorner(), EntityService.alertNoise(), getVentPlayers(), isSameCorridorAxis(), setDestination() (+3 more)

### Community 11 - "pickRetreatTile"
Cohesion: 0.39
Nodes (8): EntityService.teleportToTile(), EntityService.tileKeyToWorld(), isCornerTile(), pickClosestCornerForScramble(), pickCorridorPeekCorner(), pickRetreatTile(), positionRig(), MapLayout.getTileByKey()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `NetContracts.getRemoteEvent` to `HeadlampController.luau`, `SafeRoomUI.luau`, `PlayerStateService.luau`, `RoundService.luau`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `pickCorridorPeekCorner()` (e.g. with `MapLayout.getNeighbors()` and `MapLayout.getTileByKey()`) actually correct?**
  _`pickCorridorPeekCorner()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Why does `RoundService.init()` connect `RoundService.luau` to `RepairService.luau`, `NetContracts.getRemoteEvent`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Why does `EntityService.worldToTileKey()` connect `MapLayout.luau` to `pickRetreatTile`, `updateDetectionAndElimination`, `EntityService.luau`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._