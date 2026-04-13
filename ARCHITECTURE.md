# Architecture

## Core Principle

Game is deterministic, tick-driven, and state-driven.

Flow:

```text
Input / AI
  -> CommandBuffer (tick-stamped)
  -> TickManager.advance()
  -> Simulation systems mutate authoritative GameState
  -> StateHash / ReplayLog
  -> ClientState + Renderer + CommandPanel read-only presentation
```

## Separation Of Concerns

| Layer | Folder | Responsibility |
|-------|--------|----------------|
| Match configuration | `simulation/match_config.gd` | Headless data object: faction colors, AI timing, map dims. Passed from pregame into gameplay. |
| Content definitions | `simulation/game_definitions.gd` | Single source of truth for costs, durations, stats, supply, render colors, prerequisites, defaults, normalized entity creation |
| Authoritative state | `simulation/game_state.gd` | Entity/resource/map/occupancy data and typed read helpers; no gameplay simulation logic |
| Simulation systems | `simulation/systems/` | Only place that mutates `GameState` |
| Commands | `commands/` | Intent objects, tick-stamped, no direct state mutation |
| Runtime | `runtime/` | Tick loop, command buffering, replay, state hash, controller injection |
| Client | `client/` | Input translation, selection, camera, command panel, feedback |
| Rendering | `rendering/` | Read-only drawing from game state + client state |
| Scenes | `scenes/` | Entry points only: pregame screen and gameplay scene |

## Folder Structure

```text
simulation/
  game_state.gd
  game_definitions.gd
  deterministic_pathfinder.gd
  enemy_ai_controller.gd
  match_config.gd          ← Phase 31: match-level config (colors, AI timing)
  visibility.gd
  strategic_timing.gd
  food_readiness.gd

  systems/
    build_command_system.gd
    move_command_system.gd
    gather_command_system.gd
    combat_system.gd
    movement_system.gd
    worker_economy_system.gd
    structure_economy_system.gd
    production_system.gd
    debug_command_system.gd

commands/
  command.gd
  move_unit_command.gd
  gather_resource_command.gd
  return_cargo_command.gd
  build_structure_command.gd
  assign_construction_command.gd
  attack_command.gd
  attack_move_command.gd   ← Phase 28
  queue_production_command.gd
  set_rally_point_command.gd
  debug_increment_command.gd

runtime/
  tick_manager.gd
  command_buffer.gd
  replay_log.gd
  state_hasher.gd

client/
  client_state.gd
  input_handler.gd
  command_panel.gd

rendering/
  renderer.gd

scenes/
  pregame.gd / pregame.tscn          ← main scene; difficulty selector → MatchConfig
  prototype_gameplay.gd / .tscn      ← gameplay; receives MatchConfig via set_match_config()
  smoke_test.gd / smoke_test.tscn

tests/
  (20 headless regression tests — see TASKS.md)
```

## Authoritative Entity Model

All entities remain plain `Dictionary` objects stored in `game_state.entities`.
There is no large OOP entity rewrite.

Entity types:
- `unit`
- `structure`
- `stockpile`
- `resource_node`

The schema is normalized through `simulation/game_definitions.gd` and `GameState.get_entity_dict()`.

**Critical rule**: `get_entity_dict()` calls `normalize_entity(entity.duplicate(true))` and returns a **copy**, not a reference. Any field written to the copy must be explicitly written back to `game_state.entities[id]`. Any new unit field must be added to the `_normalize_unit_entity` whitelist in `game_definitions.gd` or it will be silently stripped on every read.

## Definition-Driven Content Layer

`simulation/game_definitions.gd` is the single source of truth for:

- building costs
- unit production costs
- construction durations
- production durations
- supply provided
- population cost
- hp / max_hp defaults
- combat defaults (attack_damage, attack_range_cells, attack_cooldown_ticks)
- combat role-to-role damage multipliers
- vision radius per unit/building type
- render colors
- prerequisites
- structure production relationships
- normalized entity constructors

Main data groups:

```gdscript
GameDefinitions.BUILDINGS
GameDefinitions.UNITS
GameDefinitions.SPECIAL_STRUCTURES
GameDefinitions.RESOURCE_NODES
GameDefinitions.STOCKPILE_PRODUCES
GameDefinitions.BASE_POPULATION_CAP
```

Main constructors:

```gdscript
GameDefinitions.create_unit_entity(...)
GameDefinitions.create_structure_entity(...)
GameDefinitions.create_stockpile_entity(...)
GameDefinitions.create_resource_node_entity(...)
GameDefinitions.normalize_entity(entity_dict)
```

## Normalized Schema Shape

### Units
Common schema:
- `id`, `entity_type`, `unit_role`, `owner_id`
- `grid_position`, `move_target`, `path_cells`, `has_move_target`
- `worker_task_state` (idle/to_resource/gathering/to_stockpile/depositing/to_construction/to_rally/to_target/attacking/attack_moving)
- `interaction_slot_cell`, `traffic_state`, `movement_wait_ticks`
- `hp`, `max_hp`
- `attack_target_id`, `attack_cooldown_remaining`, `attack_damage`, `attack_cooldown_ticks`, `attack_range_cells`
- `attack_move_target_cell` — destination for attack-move; `(-1,-1)` when not attack-moving
- `population_cost`, `vision_radius_cells`

Worker-specific fields:
- `assigned_resource_node_id`, `assigned_stockpile_id`, `assigned_construction_site_id`
- `carried_resource_type`, `carried_amount`, `carry_capacity`
- `harvest_amount`, `gather_duration_ticks`, `deposit_duration_ticks`, `gather_progress_ticks`

### Structures / Stockpile
- `id`, `entity_type`, `structure_type`, `owner_id`, `grid_position`
- `is_constructed`, `construction_progress_ticks`, `construction_duration_ticks`, `assigned_builder_id`
- `hp`, `max_hp`, `supply_provided`, `vision_radius_cells`
- `production_queue_count`, `production_progress_ticks`, `production_duration_ticks`, `produced_unit_type`, `production_blocked`
- `rally_mode`, `rally_cell`, `rally_target_id`

### Resource Nodes
- `id`, `entity_type`, `resource_type`, `grid_position`
- `remaining_amount`, `max_amount`, `is_gatherable`, `is_depleted`

## GameState Responsibilities

`simulation/game_state.gd` — authoritative data + typed helper access only.

Key helpers:
- entity reads (get_entity_dict, get_entity_type, get_entity_grid_position, …)
- map / occupancy reads (is_cell_blocked, is_cell_occupied, …)
- resource accounting
- prerequisite checking
- production affordability
- population used / queued / cap
- damageability / gatherability queries
- interaction slot assignment (`get_interaction_slot_for_worker` — greedy nearest-first deconfliction)
- static blocker cache (`static_blocker_cells` — O(1) per-cell lookup for pathfinding)
- visibility helpers (`get_entity_vision_radius`)

No gameplay simulation logic inside `GameState`.

## Match Configuration Flow

```text
pregame.tscn (main scene)
  → user picks difficulty
  → builds MatchConfig (colors, AI timing, map dims)
  → loads prototype_gameplay.tscn
  → calls gameplay_node.set_match_config(cfg)

prototype_gameplay._ready()
  → if _match_config == null: use MatchConfig defaults (safe direct launch)
  → enemy_ai_controller.configure(_match_config)
  → renderer.configure(game_state, client_state, CELL_SIZE, _match_config)
```

`MatchConfig` is headless (`RefCounted`), no Node dependency. Defaults are "Normal" difficulty so direct scene launch always works.

## System Execution Order Per Tick

1. `BuildCommandSystem`
2. `MoveCommandSystem`
3. `GatherCommandSystem`
4. `CombatSystem`
5. `MovementSystem`
6. `WorkerEconomySystem`
7. `StructureEconomySystem`
8. `ProductionSystem`

This ordering is intentional and part of the deterministic model.

## Traffic / Movement Priority

`TRAFFIC_PRIORITY_BY_TASK` in `movement_system.gd` (lower = higher priority):

| Priority | Task states |
|----------|-------------|
| 0 | depositing |
| 1 | to_stockpile |
| 2 | gathering |
| 3 | to_resource, to_construction, to_target, attack_moving |
| 4 | to_rally, idle |

## Runtime / Determinism Model

- `TickManager` runs the simulation at 10 Hz
- commands execute only on stamped ticks
- AI emits commands for future ticks through the same pipeline as player input
- stable IDs and stable iteration order are used throughout
- state hashing records authoritative post-tick state
- client-side interpolation exists only for visual smoothness; does not affect authoritative positions

## Visibility Model

- `simulation/visibility.gd` — pure read-side, no GameState mutation
- Manhattan distance model, map-boundary clamped
- `compute_visible_cells(game_state, owner_id)` — called once per `_draw()` frame, result cached in renderer
- renderer gates enemy unit/structure drawing on `_player_visible_cells`
- renderer maintains `_seen_enemy_structures` — client-side ghost memory for previously-seen-but-not-visible enemy structures (dimmed, no HP bar)

## Current Gameplay Coverage

- multi-unit selection and movement
- blocked terrain and occupancy
- deterministic BFS pathfinding with static blocker cache
- worker gather/deposit loop (wood + stone + food)
- deterministic nearest-first interaction slot assignment
- traffic / deadlock relief with repath-after-wait
- building placement and construction
- farm passive food income
- military / economy production
- population/supply cap
- combat with role-to-role damage multipliers
- attack-move command (soldiers hunt enemies while advancing)
- producer rally points
- deterministic enemy AI with staged pressure
- win / lose conditions
- strategic timing summary in HUD
- food readiness analysis in HUD
- vision-gated rendering + last-seen ghost structures
- pregame difficulty selection

## Rules

- systems are the only place that mutate `GameState`
- no simulation logic inside `GameState`
- no direct input → state mutation
- no direct AI → state mutation
- client state is never authoritative
- all content/defaults/stat values belong in `game_definitions.gd`
- authoritative positions remain integer grid cells
- any new unit entity field must be added to `_normalize_unit_entity` whitelist or it will be stripped
