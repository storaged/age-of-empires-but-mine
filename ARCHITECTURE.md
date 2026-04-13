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
| Content definitions | `simulation/game_definitions.gd` | Single source of truth for costs, durations, stats, supply, render colors, prerequisites, defaults, normalized entity creation |
| Authoritative state | `simulation/game_state.gd` | Entity/resource/map/occupancy data and typed read helpers; no gameplay simulation logic |
| Simulation systems | `simulation/systems/` | Only place that mutates `GameState` |
| Commands | `commands/` | Intent objects, tick-stamped, no direct state mutation |
| Runtime | `runtime/` | Tick loop, command buffering, replay, state hash, controller injection |
| Client | `client/` | Input translation, selection, camera, command panel, feedback |
| Rendering | `rendering/` | Read-only drawing from game state + client state |

## Folder Structure

```text
simulation/
  game_state.gd
  game_definitions.gd
  deterministic_pathfinder.gd
  enemy_ai_controller.gd

  systems/
    build_command_system.gd
    move_command_system.gd
    gather_command_system.gd
    combat_system.gd
    movement_system.gd
    worker_economy_system.gd
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
  queue_production_command.gd
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
  prototype_gameplay.gd
  prototype_gameplay.tscn
  smoke_test.gd
  smoke_test.tscn

tests/
  gather_test.gd
  construction_test.gd
  combat_test.gd
  stone_prerequisite_test.gd
  ai_winlose_test.gd
  population_supply_test.gd
  entity_schema_test.gd
```

## Authoritative Entity Model

All entities remain plain `Dictionary` objects stored in `game_state.entities`.
There is no large OOP entity rewrite.

Entity types:
- `unit`
- `structure`
- `stockpile`
- `resource_node`

The schema is now more normalized through `simulation/game_definitions.gd` and `GameState.get_entity_dict()`.

## Definition-Driven Content Layer

`simulation/game_definitions.gd` is the single source of truth for:

- building costs
- unit production costs
- construction durations
- production durations
- supply provided
- population cost
- hp / max_hp defaults
- combat defaults
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
Units now normalize around a common schema including:
- `id`
- `entity_type`
- `unit_role`
- `owner_id`
- `grid_position`
- `move_target`
- `path_cells`
- `has_move_target`
- `worker_task_state`
- `interaction_slot_cell`
- `traffic_state`
- `hp`
- `max_hp`
- `attack_target_id`
- `attack_cooldown_remaining`
- `attack_damage`
- `attack_cooldown_ticks`
- `population_cost`

Worker-specific fields remain present but standardized:
- `assigned_resource_node_id`
- `assigned_stockpile_id`
- `assigned_construction_site_id`
- `carried_resource_type`
- `carried_amount`
- `carry_capacity`
- `harvest_amount`
- `gather_duration_ticks`
- `deposit_duration_ticks`
- `gather_progress_ticks`

Workers are now properly compatible with generic damageability.

### Structures / Stockpile
Structures and stockpile normalize around:
- `id`
- `entity_type`
- `structure_type`
- `owner_id`
- `grid_position`
- `is_constructed`
- `construction_progress_ticks`
- `construction_duration_ticks`
- `assigned_builder_id`
- `hp`
- `max_hp`
- `supply_provided`
- `production_queue_count`
- `production_progress_ticks`
- `production_duration_ticks`
- `produced_unit_type`
- `production_blocked`

### Resource Nodes
Resource nodes normalize around:
- `id`
- `entity_type`
- `resource_type`
- `grid_position`
- `remaining_amount`
- `max_amount`
- `is_gatherable`
- `is_depleted`

## GameState Responsibilities

`simulation/game_state.gd` remains authoritative data + typed helper access only.

Important helper categories:
- entity reads
- map / occupancy reads
- resource accounting
- prerequisite checking
- production affordability
- population used / queued / cap
- damageability / gatherability queries

The key discipline is unchanged:
- no gameplay simulation logic inside `GameState`
- systems still own all authoritative mutation

## System Execution Order Per Tick

1. `BuildCommandSystem`
2. `MoveCommandSystem`
3. `GatherCommandSystem`
4. `CombatSystem`
5. `MovementSystem`
6. `WorkerEconomySystem`
7. `ProductionSystem`

This ordering is intentional and part of the deterministic model.

## Runtime / Determinism Model

- `TickManager` runs the simulation at 10 Hz
- commands execute only on stamped ticks
- AI emits commands for future ticks through the same pipeline as player input
- stable IDs and stable iteration order are used throughout
- state hashing records authoritative post-tick state

Client-side interpolation exists only for visual smoothness and does not affect authoritative positions.

## Current Gameplay Coverage

Implemented systems now include:
- multi-unit selection and movement
- blocked terrain and occupancy
- deterministic BFS pathfinding
- worker gather/deposit loop
- deterministic worker slot assignment
- traffic/deadlock relief
- building placement and construction
- military/economy production
- combat
- deterministic enemy AI
- win/lose
- population/supply
- production/construction readability in UI

## Current Tests

- `tests/gather_test.gd`
- `tests/construction_test.gd`
- `tests/combat_test.gd`
- `tests/stone_prerequisite_test.gd`
- `tests/ai_winlose_test.gd`
- `tests/population_supply_test.gd`
- `tests/entity_schema_test.gd`

## Rules

- systems are the only place that mutate `GameState`
- no simulation logic inside `GameState`
- no direct input -> state mutation
- no direct AI -> state mutation
- client state is never authoritative
- all content/defaults/stat values belong in `game_definitions.gd`
- authoritative positions remain integer grid cells

## Architectural Implications For Next Work

The project is now in a better place to support future:
- armor / resistances
- upgrades
- richer combat stats
- vision / fog of war
- multiplayer serialization hardening

But none of those should bypass the current authoritative schema and system boundaries.
