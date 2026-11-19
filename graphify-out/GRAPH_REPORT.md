# Graph Report - roblox-project  (2026-11-19)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 37 nodes · 51 edges · 7 communities (3 shown, 4 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `81fb1d82`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 4

## God Nodes (most connected - your core abstractions)
1. `HeadlampController.init()` - 6 edges
2. `NetContracts.getRemoteEvent()` - 4 edges
3. `applyLocalLightState()` - 3 edges
4. `createLocalHud()` - 3 edges
5. `updateHud()` - 3 edges
6. `watchRemotePlayer()` - 3 edges
7. `PlayerStateService.init()` - 3 edges
8. `setupCollisionGroups()` - 3 edges
9. `applyPart0Transform()` - 3 edges
10. `CrawlController.init()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `HeadlampController.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/client/HeadlampController.luau → src/shared/NetContracts.luau
- `PlayerStateService.init()` --calls--> `NetContracts.getRemoteEvent()`  [INFERRED]
  src/server/PlayerStateService.luau → src/shared/NetContracts.luau

## Import Cycles
- None detected.

## Communities (7 total, 4 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.42
Nodes (7): applyLocalLightState(), attachTeammateLight(), createLocalHeadlampRig(), createLocalHud(), HeadlampController.init(), updateHud(), watchRemotePlayer()

### Community 1 - "Community 1"
Cohesion: 0.33
Nodes (7): clearCharacterConnections(), ensureCollisionGroup(), onCharacterAdded(), onPlayerAdded(), onPlayerRemoving(), PlayerStateService.init(), setupCollisionGroups()

### Community 2 - "Community 2"
Cohesion: 0.48
Nodes (5): applyPart0Transform(), CrawlController.init(), getRestC0Rotation(), updateCharacterCrawlPose(), updateLocalMovementAndCamera()

## Knowledge Gaps
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `NetContracts.getRemoteEvent()` connect `Community 4` to `Community 0`, `Community 1`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `NetContracts.getRemoteEvent()` (e.g. with `HeadlampController.init()` and `PlayerStateService.init()`) actually correct?**
  _`NetContracts.getRemoteEvent()` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Why does `HeadlampController.init()` connect `Community 0` to `Community 4`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `PlayerStateService.init()` connect `Community 1` to `Community 4`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._