# Architecture

## Core Principle

Game is deterministic, tick-driven, and state-driven.

Flow:
```
Input/AI → CommandBuffer (tick-stamped) → TickManager.advance() → Systems → GameState → StateHash/ReplayLog
                                                                                       ↓
                                                                             ClientState + Renderer (read-only)
```

## Separation of Concerns

| Layer | Folder | Responsibility |
|-------|--------|----------------|
| Content definitions | `simulation/game_definitions.gd` | Single source of truth: costs, durations, render colors, spawn templates, prerequisites |
| Authoritative state | `simulation/game_state.gd` | Entity data, resources, occupancy, map. No logic. |
| Simulation systems | `simulation/systems/` | Only place that mutates `GameState` |
| Commands | `commands/` | Intent objects, tick-stamped. No state mutation. |
| Runtime | `runtime/` | Tick loop, command buffer, replay log, state hasher |
| Client | `client/` | Input translation, selection, camera, hover, command panel UI |
| Rendering | `rendering/` | Reads game state + client state; draws nothing that requires authoritative data |

## Folder Structure

```
simulation/
  game_state.gd            — authoritative entity/resource/occupancy data
  game_definitions.gd      — BUILDINGS and UNITS const dicts; all static helper methods
  deterministic_pathfinder.gd

  systems/
    build_command_system.gd    — validates + places structures; deducts costs; enforces prerequisites
    move_command_system.gd     — issues move targets
    gather_command_system.gd   — assigns workers to resource nodes or construction sites
    combat_system.gd           — resolves attacks, applies damage, removes dead entities
    movement_system.gd         — advances unit positions along paths; stall recovery
    worker_economy_system.gd   — gather/deposit tick loop; construction progress
    production_system.gd       — unit training tick loop; spawns units on completion
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
  tick_manager.gd    — advances simulation at 10 Hz; buffers and executes commands
  command_buffer.gd
  replay_log.gd
  state_hasher.gd

client/
  client_state.gd    — camera, selection, hover, indicators, placement mode, visual interpolation
  input_handler.gd   — translates mouse/keyboard input into SimulationCommands or client state changes
  command_panel.gd   — 130px bottom panel: selection detail label + 8 action buttons + DBG toggle

rendering/
  renderer.gd        — Node2D; reads game_state + client_state; draws grid, units, structures, overlays

scenes/
  prototype_gameplay.tscn / prototype_gameplay.gd  — main scene; wires all layers together
  smoke_test.tscn / smoke_test.gd

tests/
  gather_test.gd             — worker gather/deposit loop
  construction_test.gd       — building placement and worker construction assignment
  combat_test.gd             — soldier attack, damage, entity removal
  stone_prerequisite_test.gd — stone gathering, prerequisite chain, archery range production
```

## GameState Entity Model

All entities are plain `Dictionary` objects stored in `game_state.entities: Dictionary`.
Entity types: `"unit"`, `"structure"`, `"stockpile"`, `"resource_node"`.
All entity reads go through typed `GameState` helper methods (`get_entity_type`, `get_entity_unit_role`, etc.).

## GameDefinitions Content Model

`simulation/game_definitions.gd` is the **single source of truth** for all game content:

```gdscript
GameDefinitions.BUILDINGS       # costs, duration, prerequisites, produces, render colors
GameDefinitions.UNITS           # production_costs, duration, role, stats
GameDefinitions.STOCKPILE_PRODUCES

# Key static methods:
get_building_costs(type)            → Dictionary
get_building_prerequisite(type)     → String
get_building_produces(type)         → String
get_building_render_colors(type)    → {"base": Color, "inner": Color, "border": Color}
get_unit_production_costs(type)     → Dictionary
format_costs(costs)                 → "25 wood, 20 stone"
format_costs_short(costs)           → "25W 20S"
create_unit_entity(...)             → Dictionary
```

**Do not hardcode costs, durations, or render colors outside this file.**

## Simulation Tick Rate

Fixed at 10 Hz (`TICK_DURATION = 0.1s` in `TickManager`). Visual frame rate is independent; client interpolates between authoritative tick positions.

## System Execution Order Per Tick

1. `BuildCommandSystem` — process pending build/placement commands
2. `MoveCommandSystem` — apply move targets
3. `GatherCommandSystem` — assign gather/return/construction tasks
4. `CombatSystem` — resolve attacks
5. `MovementSystem` — advance paths, stall recovery
6. `WorkerEconomySystem` — gather/deposit/construct progress
7. `ProductionSystem` — training progress, unit spawn

## Command Panel (client/command_panel.gd)

Anchored to bottom of viewport (full width, 130px tall). Never mutates simulation state — emits signals only:

| Signal | When |
|--------|------|
| `build_requested(structure_type)` | Worker selected + build button clicked |
| `train_requested(producer_id)` | Production building selected + Train clicked |
| `debug_toggle_requested()` | DBG button clicked |
| `cancel_placement_requested()` | Cancel button clicked during placement mode |

Button state is derived each frame from `GameState` + `ClientState` — disabled with tooltip reason if prereq not met or resources insufficient.

## Current Vertical Slice

- Multiple selectable player units (workers, soldiers, archers)
- Deterministic grid movement with BFS pathfinding
- Two resource types: wood and stone
- Worker gather → carry → deposit loop for both resources
- Building prerequisite chain: house → barracks → archery range
- Worker constructs buildings (right-click construction site)
- Barracks trains soldiers, archery range trains archers
- Stockpile trains workers
- Soldiers and archers attack enemy units and enemy base
- Enemy dummy units on map (static, attackable)
- Context-sensitive command panel with clickable build/train buttons
- Debug overlay toggleable via DBG button or F3

## Rules

- Systems are the only place that mutate `GameState`
- No simulation logic inside `GameState`
- No simulation logic inside rendering or client layer
- No direct input → state mutation (input → commands only)
- Client state must never be required for authoritative simulation
- All content (costs, durations, colors) defined in `game_definitions.gd` only
- Authoritative positions are integer grid cells; smooth movement is client-only interpolation
