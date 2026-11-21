# Graph Report - roblox-project  (2026-11-20)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 161 nodes · 328 edges · 12 communities (10 shown, 2 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 39 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a4799ed7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- PlayerStateService.luau
- RoundService.luau
- RepairService.luau
- EntityService.luau
- MapLayout.luau
- CrawlController.luau
- CrawlController.luau
- SafeRoomUI.luau
- HeadlampController.luau
- SafeRoomUI.luau
- updateDetectionAndElimination

## God Nodes (most connected - your core abstractions)
1. `updateDetectionAndElimination()` - 13 edges
2. `AudioController.init()` - 13 edges
3. `startMatchServices()` - 10 edges
4. `RoundService.init()` - 9 edges
5. `RoundService.startNewRound()` - 9 edges
6. `updateNodeVisuals()` - 9 edges
7. `MapLayout.getTileByKey()` - 8 edges
8. `EntityService.alertNoise()` - 8 edges
9. `pickCorridorPeekCorner()` - 8 edges
10. `broadcastState()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `buildStatePayload()` --calls--> `RepairService.getActiveFaultSectors()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `startMatchServices()` --calls--> `RepairService.setNoiseCallback()`  [INFERRED]
  src/server/init.server.luau → src/server/RepairService.luau
- `pickBalancedFaultIds()` --calls--> `MapLayout.getRepairSlots()`  [INFERRED]
  src/server/RoundService.luau → src/shared/MapLayout.luau
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.worldToTile()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau

## Import Cycles
- None detected.

## Communities (12 total, 2 thin omitted)

### Community 0 - "PlayerStateService.luau"
Cohesion: 0.14
Nodes (31): enterChase(), enterLurk(), enterRetreat(), enterScrambleToCorner(), EntityService.alertNoise(), EntityService.teleportToTile(), EntityService.tileKeyToWorld(), EntityService.worldToTileKey() (+23 more)

### Community 1 - "RoundService.luau"
Cohesion: 0.23
Nodes (17): EntityService.getState(), EntityService.setEliminatedCallback(), startMatchServices(), RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds() (+9 more)

### Community 2 - "RepairService.luau"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 3 - "EntityService.luau"
Cohesion: 0.25
Nodes (12): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.getActiveFaultSectors(), RepairService.init() (+4 more)

### Community 4 - "MapLayout.luau"
Cohesion: 0.41
Nodes (12): AudioController.init(), AudioController.playScareSting(), checkEntityOccluded(), createSound(), ensureEntityAudio(), ensurePhantomAnchor(), ensureRepairNodeAudio(), playFadeSnippet() (+4 more)

### Community 5 - "CrawlController.luau"
Cohesion: 0.20
Nodes (3): createHud(), PanicController.init(), updateVisuals()

### Community 6 - "CrawlController.luau"
Cohesion: 0.35
Nodes (9): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), syncCameraMode(), updateCharacterPose() (+1 more)

### Community 7 - "SafeRoomUI.luau"
Cohesion: 0.31
Nodes (9): applyState(), createHud(), cycleSpectate(), formatSectors(), restoreLocalCamera(), SafeRoomUI.init(), triggerScareFlash(), NetContracts.getOrCreateRemotesFolder() (+1 more)

### Community 8 - "HeadlampController.luau"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 10 - "updateDetectionAndElimination"
Cohesion: 0.43
Nodes (7): applyCrawlLimbs(), bindEntityModel(), composeBone(), findAndBindEntity(), rotAround(), setTarget(), updateAnimation()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `SafeRoomUI.luau` to `RoundService.luau`, `RepairService.luau`, `MapLayout.luau`, `CrawlController.luau`, `HeadlampController.luau`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `startMatchServices()` (e.g. with `EntityService.alertNoise()` and `EntityService.getState()`) actually correct?**
  _`startMatchServices()` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Should `PlayerStateService.luau` be split into smaller, more focused modules?**
  _Cohesion score 0.13513513513513514 - nodes in this community are weakly interconnected._
- **Why does `startMatchServices()` connect `RoundService.luau` to `PlayerStateService.luau`, `EntityService.luau`, `CrawlController.luau`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `RoundService.init()` (e.g. with `startMatchServices()` and `RepairService.init()`) actually correct?**
  _`RoundService.init()` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Why does `RoundService.init()` connect `RoundService.luau` to `EntityService.luau`, `SafeRoomUI.luau`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._