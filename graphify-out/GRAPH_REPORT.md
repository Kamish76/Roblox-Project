# Graph Report - roblox-project  (2026-11-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 86 nodes · 154 edges · 10 communities (7 shown, 3 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0af3b032`
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

## God Nodes (most connected - your core abstractions)
1. `updateNodeVisuals()` - 9 edges
2. `RoundService.init()` - 8 edges
3. `broadcastState()` - 7 edges
4. `RoundService.startNewRound()` - 7 edges
5. `buildStatePayload()` - 6 edges
6. `RoundService.trySignOff()` - 6 edges
7. `HeadlampController.init()` - 6 edges
8. `NetContracts.getRemoteEvent()` - 6 edges
9. `RepairService.init()` - 5 edges
10. `setupNode()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `buildStatePayload()` --calls--> `RepairService.getActiveFaultSectors()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau
- `RoundService.startNewRound()` --calls--> `PlayerStateService.transitionToSafeRoom()`  [INFERRED]
  src/server/RoundService.luau → src/server/PlayerStateService.luau
- `RoundService.startNewRound()` --calls--> `RepairService.activateFaults()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau
- `RoundService.init()` --calls--> `RepairService.init()`  [INFERRED]
  src/server/RoundService.luau → src/server/RepairService.luau

## Import Cycles
- None detected.

## Communities (10 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.23
Nodes (12): clearCharacterConnections(), ensureCollisionGroup(), getSafeRoomReturnCFrame(), getVentEntryCFrame(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init() (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.31
Nodes (11): getFaultLight(), getPrompt(), getSparks(), isPlayerAliveNear(), RepairService.activateFaults(), RepairService.completeNode(), RepairService.getActiveFaultSectors(), RepairService.init() (+3 more)

### Community 2 - "Community 2"
Cohesion: 0.36
Nodes (12): RepairService.getRepairedCount(), broadcastState(), buildStatePayload(), formatSectorList(), pickBalancedFaultIds(), RoundService.getState(), RoundService.init(), RoundService.startNewRound() (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.24
Nodes (5): MapLayout.findPath(), MapLayout.getNeighbors(), MapLayout.getRepairSlots(), MapLayout.getTile(), MapLayout.key()

### Community 4 - "Community 4"
Cohesion: 0.53
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 5 - "Community 5"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 6 - "Community 6"
Cohesion: 0.39
Nodes (6): applyState(), createHud(), formatSectors(), SafeRoomUI.init(), NetContracts.getOrCreateRemotesFolder(), NetContracts.getRemoteEvent()

## Knowledge Gaps
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 6` to `Community 0`, `Community 2`, `Community 5`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `RoundService.init()` (e.g. with `RepairService.init()` and `NetContracts.getRemoteEvent()`) actually correct?**
  _`RoundService.init()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Why does `RoundService.init()` connect `Community 2` to `Community 1`, `Community 6`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `RoundService.startNewRound()` (e.g. with `PlayerStateService.transitionToSafeRoom()` and `RepairService.activateFaults()`) actually correct?**
  _`RoundService.startNewRound()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Why does `RoundService.startNewRound()` connect `Community 2` to `Community 0`, `Community 1`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._