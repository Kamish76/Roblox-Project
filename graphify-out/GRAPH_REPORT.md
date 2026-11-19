# Graph Report - roblox-project  (2026-11-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 53 nodes · 78 edges · 8 communities (4 shown, 4 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `90e66725`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 5

## God Nodes (most connected - your core abstractions)
1. `HeadlampController.init()` - 6 edges
2. `CrawlController.init()` - 5 edges
3. `isPlayerCrawling()` - 5 edges
4. `PlayerStateService.setStance()` - 4 edges
5. `applyStancePhysics()` - 4 edges
6. `updateCharacterPose()` - 4 edges
7. `updateLocalMovementAndCamera()` - 4 edges
8. `NetContracts.getRemoteEvent()` - 4 edges
9. `onCharacterAdded()` - 3 edges
10. `PlayerStateService.init()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau
- `HeadlampController.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/client/HeadlampController.luau → src/shared/NetContracts.luau

## Import Cycles
- None detected.

## Communities (8 total, 4 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.24
Nodes (10): clearCharacterConnections(), ensureCollisionGroup(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init(), PlayerStateService.setStance(), PlayerStateService.transitionToSafeRoom() (+2 more)

### Community 1 - "Community 1"
Cohesion: 0.24
Nodes (4): MapLayout.findPath(), MapLayout.getNeighbors(), MapLayout.getTile(), MapLayout.key()

### Community 2 - "Community 2"
Cohesion: 0.53
Nodes (8): applyPart0Transform(), applyStancePhysics(), CrawlController.init(), enforceLocalHumanoid(), getRestC0Rotation(), isPlayerCrawling(), updateCharacterPose(), updateLocalMovementAndCamera()

### Community 3 - "Community 3"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

## Knowledge Gaps
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 5` to `Community 0`, `Community 3`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **Why does `PlayerStateService.init()` connect `Community 0` to `Community 5`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `HeadlampController.init()` connect `Community 3` to `Community 5`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._