# Graph Report - roblox-project  (2026-11-20)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 130 nodes · 260 edges · 14 communities (12 shown, 2 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 27 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `5e2180e4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PlayerStateService.luau
- RoundService.luau
- RepairService.luau
- EntityService.luau
- MapLayout.luau
- CrawlController.luau
- shared_waitforchild
- NetContracts.getRemoteEvent
- HeadlampController.luau
- SafeRoomUI.luau
- updateDetectionAndElimination
- pickRetreatTile

## God Nodes (most connected - your core abstractions)
1. `updateDetectionAndElimination()` - 11 edges
2. `updateNodeVisuals()` - 9 edges
3. `EntityService.tryRepairCornerPeek()` - 9 edges
4. `broadcastState()` - 8 edges
5. `RoundService.init()` - 8 edges
6. `RoundService.startNewRound()` - 8 edges
7. `NetContracts.getRemoteEvent()` - 8 edges
8. `EntityService.alertNoise()` - 7 edges
9. `pickRetreatTile()` - 7 edges
10. `EntityService.worldToTileKey()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau
- `RoundService.startNewRound()` --calls--> `PlayerStateService.transitionToSafeRoom()`  [INFERRED]
  src/server/RoundService.luau → src/server/PlayerStateService.luau
- `buildStatePayload()` --calls--> `RepairService.getActiveFaultSectors()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `pickBalancedFaultIds()` --calls--> `MapLayout.getRepairSlots()`  [INFERRED]
  src/server/RoundService.luau → src/shared/MapLayout.luau

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
Cohesion: 0.23
Nodes (7): EntityService.tryRepairCornerPeek(), getVentPlayers(), hasLineOfSight(), hasLineOfSightFrom(), isPlayerLookingAtEntity(), positionLurkPeekRig(), updatePanicLoop()

### Community 4 - "MapLayout.luau"
Cohesion: 0.24
Nodes (9): EntityService.worldToTileKey(), pickPatrolDestination(), MapLayout.findPath(), MapLayout.getNeighbors(), MapLayout.getRepairSlots(), MapLayout.getTile(), MapLayout.key(), MapLayout.tileToWorld() (+1 more)

### Community 5 - "CrawlController.luau"
Cohesion: 0.38
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 6 - "shared_waitforchild"
Cohesion: 0.24
Nodes (3): createHud(), PanicController.init(), updateVisuals()

### Community 7 - "NetContracts.getRemoteEvent"
Cohesion: 0.42
Nodes (7): AudioController.init(), AudioController.playScareSting(), createSound(), ensureEntityAudio(), ensureFaultHum(), NetContracts.getOrCreateRemotesFolder(), NetContracts.getRemoteEvent()

### Community 8 - "HeadlampController.luau"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 9 - "SafeRoomUI.luau"
Cohesion: 0.46
Nodes (7): applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera(), SafeRoomUI.init(), triggerScareFlash()

### Community 10 - "updateDetectionAndElimination"
Cohesion: 0.57
Nodes (7): enterChase(), enterRetreat(), EntityService.alertNoise(), pickLurkTileForPlayer(), setDestination(), setState(), updateDetectionAndElimination()

### Community 11 - "pickRetreatTile"
Cohesion: 0.60
Nodes (5): EntityService.teleportToTile(), EntityService.tileKeyToWorld(), pickRetreatTile(), positionRig(), MapLayout.getTileByKey()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `NetContracts.getRemoteEvent` to `PlayerStateService.luau`, `RoundService.luau`, `shared_waitforchild`, `HeadlampController.luau`, `SafeRoomUI.luau`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Why does `RoundService.init()` connect `RoundService.luau` to `RepairService.luau`, `NetContracts.getRemoteEvent`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `RoundService.startNewRound()` connect `RoundService.luau` to `PlayerStateService.luau`, `RepairService.luau`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._