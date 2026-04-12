# Development Tasks

## Completed

### Phase 1 — Deterministic Core
- Project scaffold, authoritative `GameState`, fixed-step `TickManager`
- Tick-stamped `CommandBuffer`, replay log, authoritative state hashing
- Deterministic smoke test scene

### Phase 2 — First Playable Slice
- Top-down 2D prototype scene, grid-backed map rendering
- Controllable units, click selection, move commands
- Client-side interpolation over authoritative tick movement
- HUD + F3 debug overlay

### Phase 3 — Multi-Unit Control
- Multiple controllable units, marquee drag selection
- Deterministic group destination assignment

### Phase 4 — Obstacles And Occupancy
- Authoritative blocked cells, obstacle rendering
- Rejected blocked move targets, deterministic occupancy reservation

### Phase 5 — Deterministic Pathfinding
- Deterministic BFS grid pathfinding through authoritative simulation
- Routed all move commands through path generation
- Preserved occupancy waiting behavior

### Phase 6 — Worker Economy Slice
- Worker-role units, resource nodes (wood), stockpile/base structure
- Gather command through tick-stamped command pipeline
- Deterministic worker gather → return → deposit loop
- HUD resource totals, selected worker task summary

### Phase 7 — Combat And Building Production Slice
- `AssignConstructionCommand`: workers build structures (deterministic progress ticks)
- `BuildCommandSystem`: validates placement, deducts resources, spawns construction site
- `ProductionSystem`: trains units from stockpile and production buildings
- `CombatSystem`: soldiers attack enemy units and base
- `AttackCommand`, `QueueProductionCommand`, `AssignConstructionCommand`
- Enemy dummy units + enemy base with HP; win by destroying enemy base

### Phase 8 — Extensibility And Movement Robustness
- `simulation/game_definitions.gd`: central content model for all costs, durations, render colors, spawn templates
- Removed hardcoded content branching from systems, renderer, input handler
- Movement stall recovery: MovementSystem detects blocker idle → clears path → forces re-plan
- All helpers (`can_afford_building`, `deduct_building_cost`, `is_prerequisite_met`, etc.) on `GameState`
- `gather_test.gd`, `construction_test.gd`, `combat_test.gd` headless tests

### Phase 9 — Multi-Resource And Prerequisite Content
- Stone resource type: stone nodes on map, workers gather stone
- `archery_range` building (requires barracks), `barracks` (requires house)
- Archer unit: costs wood + stone, trains from archery range, has bow icon
- Multi-resource cost model in `GameDefinitions.BUILDINGS` and `UNITS`
- `stone_prerequisite_test.gd` with 4 tests (stone gather, prereq rejection, prereq chain, archer production)
- Data-driven prerequisite checking via `game_state.is_prerequisite_met()`

### Phase 10 — Command Panel UI
- `client/command_panel.gd`: 130px bottom panel, always visible
- Left: context-sensitive `RichTextLabel` (selection detail, construction/production status)
- Right: up to 8 clickable action buttons (4×2 grid)
  - Workers selected → build buttons for each building (disabled + reason if prereq/resources missing)
  - Production building selected → Train button (disabled if can't afford)
  - Placement mode → Cancel Build button
- Far right: DBG toggle button (replaces F3-only debug access)
- Hotkeys B/N/M/Q preserved as shortcuts, delegate to same handlers as buttons
- Renderer: building colors now data-driven via `GameDefinitions.get_building_render_colors()`
- `format_costs_short()` for compact button labels ("30W", "25W 20S")

## Next Recommended Phase

### Phase 11 — Enemy AI And Win Condition
- Enemy AI that issues the same `SimulationCommand` objects as the player
- Enemy spawns soldiers from its base on a timer (via `QueueProductionCommand`)
- Enemy soldiers pathfind toward and attack player stockpile
- Win condition: enemy base HP reaches 0
- Lose condition: player stockpile destroyed
- Simple "You Win" / "You Lose" overlay
- Keep AI deterministic (no RNG beyond existing state hash model)

### Phase 12 — Multiplayer Lockstep Foundation
- Determinism stress test: two independent simulation runs must produce identical hashes
- Lockstep tick synchronization protocol (local 2-player or client/server stub)
- Desync detection via state hash comparison
- Replay export and replay load verification

## Rules
- Keep work incremental and runnable
- Preserve deterministic simulation boundary at all times
- Commands are intent only — never direct state mutation
- Systems are the only place that mutate authoritative `GameState`
- Client feedback may be immediate, but must stay outside `GameState`
- Prefer lean vertical slices over broad placeholder systems
