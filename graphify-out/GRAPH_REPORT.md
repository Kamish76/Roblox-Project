# Graph Report - roblox-project  (2026-11-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 109 nodes · 214 edges · 10 communities (8 shown, 2 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 21 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4f78af06`
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

## God Nodes (most connected - your core abstractions)
1. `EntityService.init()` - 12 edges
2. `updateNodeVisuals()` - 9 edges
3. `NetContracts.getRemoteEvent()` - 8 edges
4. `RoundService.init()` - 8 edges
5. `updateDetectionAndElimination()` - 7 edges
6. `broadcastState()` - 7 edges
7. `RoundService.startNewRound()` - 7 edges
8. `EntityService.alertNoise()` - 6 edges
9. `EntityService.worldToTileKey()` - 6 edges
10. `setDestination()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `EntityService.tileKeyToWorld()` --calls--> `MapLayout.tileToWorld()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.worldToTile()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau
- `buildStatePayload()` --calls--> `RepairService.getActiveFaultSectors()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `EntityService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/EntityService.luau → src/shared/NetContracts.luau
- `EntityService.worldToTileKey()` --calls--> `MapLayout.key()`  [INFERRED]
  src/server/EntityService.luau → src/shared/MapLayout.luau

## Import Cycles
- None detected.

## Communities (10 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.26
Nodes (16): computeMapOffset(), createEntityRig(), EntityService.alertNoise(), EntityService.init(), EntityService.teleportToTile(), EntityService.tileKeyToWorld(), EntityService.worldToTileKey(), hasLineOfSight() (+8 more)

### Community 1 - "Community 1"
Cohesion: 0.16
Nodes (9): createHud(), PanicController.init(), updateVisuals(), applyState(), createHud(), formatSectors(), SafeRoomUI.init(), NetContracts.getOrCreateRemotesFolder() (+1 more)

### Community 2 - "Community 2"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.27
Nodes (11): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.getActiveFaultSectors(), RepairService.init() (+3 more)

### Community 4 - "Community 4"
Cohesion: 0.36
Nodes (12): RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.getState(), RoundService.init(), RoundService.startNewRound() (+4 more)

### Community 5 - "Community 5"
Cohesion: 0.28
Nodes (7): MapLayout.findPath(), MapLayout.getNeighbors(), MapLayout.getRepairSlots(), MapLayout.getTile(), MapLayout.key(), MapLayout.tileToWorld(), MapLayout.worldToTile()

### Community 6 - "Community 6"
Cohesion: 0.53
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 7 - "Community 7"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

## Knowledge Gaps
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 1` to `Community 0`, `Community 2`, `Community 4`, `Community 7`?**
  _High betweenness centrality (0.107) - this node is a cross-community bridge._
- **Are the 6 inferred relationships involving `NetContracts.getRemoteEvent()` (e.g. with `HeadlampController.init()` and `PanicController.init()`) actually correct?**
  _`NetContracts.getRemoteEvent()` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Why does `EntityService.init()` connect `Community 0` to `Community 1`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `RoundService.init()` (e.g. with `RepairService.init()` and `NetContracts.getRemoteEvent()`) actually correct?**
  _`RoundService.init()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Why does `RoundService.init()` connect `Community 4` to `Community 1`, `Community 3`?**
  _High betweenness centrality (0.047) - this node is a cross-community bridge._