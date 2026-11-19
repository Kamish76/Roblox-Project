# Graph Report - roblox-project  (2026-11-20)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 128 nodes · 257 edges · 14 communities (12 shown, 2 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 27 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6b53d3b2`
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
- Community 9
- Community 10
- Community 11

## God Nodes (most connected - your core abstractions)
1. `updateDetectionAndElimination()` - 11 edges
2. `updateNodeVisuals()` - 9 edges
3. `EntityService.tryRepairCornerPeek()` - 9 edges
4. `broadcastState()` - 8 edges
5. `RoundService.init()` - 8 edges
6. `RoundService.startNewRound()` - 8 edges
7. `NetContracts.getRemoteEvent()` - 8 edges
8. `pickRetreatTile()` - 7 edges
9. `EntityService.worldToTileKey()` - 7 edges
10. `SafeRoomUI.init()` - 7 edges

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

### Community 0 - "Community 0"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.30
Nodes (14): RepairService.getActiveFaultSectors(), RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.checkSquadWipe(), RoundService.getState() (+6 more)

### Community 2 - "Community 2"
Cohesion: 0.27
Nodes (10): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.init(), RepairService.setNodeProgress() (+2 more)

### Community 3 - "Community 3"
Cohesion: 0.26
Nodes (5): AudioController.init(), AudioController.playScareSting(), createSound(), ensureEntityAudio(), ensureFaultHum()

### Community 4 - "Community 4"
Cohesion: 0.26
Nodes (6): EntityService.tryRepairCornerPeek(), getVentPlayers(), hasLineOfSight(), hasLineOfSightFrom(), isPlayerLookingAtEntity(), positionLurkPeekRig()

### Community 5 - "Community 5"
Cohesion: 0.33
Nodes (10): enterChase(), enterRetreat(), EntityService.alertNoise(), pickLurkTileForPlayer(), setDestination(), setState(), updateDetectionAndElimination(), updatePanicLoop() (+2 more)

### Community 6 - "Community 6"
Cohesion: 0.28
Nodes (7): EntityService.worldToTileKey(), pickPatrolDestination(), MapLayout.getRepairSlots(), MapLayout.getTile(), MapLayout.key(), MapLayout.tileToWorld(), MapLayout.worldToTile()

### Community 7 - "Community 7"
Cohesion: 0.53
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 8 - "Community 8"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 9 - "Community 9"
Cohesion: 0.46
Nodes (7): applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera(), SafeRoomUI.init(), triggerScareFlash()

### Community 10 - "Community 10"
Cohesion: 0.43
Nodes (5): createHud(), PanicController.init(), updateVisuals(), NetContracts.getOrCreateRemotesFolder(), NetContracts.getRemoteEvent()

### Community 11 - "Community 11"
Cohesion: 0.60
Nodes (5): EntityService.teleportToTile(), EntityService.tileKeyToWorld(), pickRetreatTile(), positionRig(), MapLayout.getTileByKey()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 10` to `Community 0`, `Community 1`, `Community 3`, `Community 8`, `Community 9`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `RoundService.init()` connect `Community 1` to `Community 2`, `Community 10`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `RoundService.startNewRound()` connect `Community 1` to `Community 0`, `Community 2`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._