# Graph Report - roblox-project  (2026-11-20)

## Corpus Check
- 19 files · ~28,761 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 5 file(s) not represented in the graph (top: (none) 2, .blend 1, .fbx 1)

## Summary
- 149 nodes · 304 edges · 14 communities (12 shown, 2 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6528f41c`
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
- AudioController.luau
- HeadlampController.luau
- SafeRoomUI.luau
- updateDetectionAndElimination
- pickRetreatTile

## God Nodes (most connected - your core abstractions)
1. `AudioController.init()` - 13 edges
2. `updateDetectionAndElimination()` - 13 edges
3. `updateNodeVisuals()` - 9 edges
4. `broadcastState()` - 8 edges
5. `RoundService.init()` - 8 edges
6. `RoundService.startNewRound()` - 8 edges
7. `pickCorridorPeekCorner()` - 8 edges
8. `MapLayout.getTileByKey()` - 8 edges
9. `NetContracts.getRemoteEvent()` - 8 edges
10. `EntityService.alertNoise()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `buildStatePayload()` --calls--> `RepairService.getActiveFaultSectors()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `AudioController.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/client/AudioController.luau → src/shared/NetContracts.luau
- `RoundService.startNewRound()` --calls--> `PlayerStateService.transitionToSafeRoom()`  [INFERRED]
  src/server/RoundService.luau → src/server/PlayerStateService.luau
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau

## Import Cycles
- None detected.

## Communities (14 total, 2 thin omitted)

### Community 0 - "PlayerStateService.luau"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.34
Nodes (13): RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.checkSquadWipe(), RoundService.getState(), RoundService.init() (+5 more)

### Community 2 - "RepairService.luau"
Cohesion: 0.25
Nodes (11): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.getActiveFaultSectors(), RepairService.init() (+3 more)

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

### Community 7 - "AudioController.luau"
Cohesion: 0.41
Nodes (12): AudioController.init(), AudioController.playScareSting(), checkEntityOccluded(), createSound(), ensureEntityAudio(), ensurePhantomAnchor(), ensureRepairNodeAudio(), playFadeSnippet() (+4 more)

### Community 8 - "HeadlampController.luau"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 9 - "SafeRoomUI.luau"
Cohesion: 0.14
Nodes (12): createHud(), PanicController.init(), updateVisuals(), applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera() (+4 more)

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

- **Why does `NetContracts.getRemoteEvent()` connect `SafeRoomUI.luau` to `HeadlampController.luau`, `PlayerStateService.luau`, `RoundService.luau`, `AudioController.luau`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Should `SafeRoomUI.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Why does `RoundService.init()` connect `RoundService.luau` to `SafeRoomUI.luau`, `RepairService.luau`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `AudioController.init()` connect `AudioController.luau` to `SafeRoomUI.luau`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._