# Handoff to Codex

Project: Age Of Empires But Mine  
Engine: Godot 4.6.2  
Language: GDScript  
Repo: storaged/age-of-empires-but-mine

## What Exists Now

This is a deterministic RTS prototype with a real gameplay loop already in place.

Current implemented slice:
- authoritative 10 Hz simulation
- tick-stamped command pipeline
- replay/state hashing foundation
- multi-unit selection and movement
- blocked terrain, occupancy, deterministic BFS pathfinding
- worker economy for `wood` and `stone`
- building placement, construction, and prerequisite chain
- production from stockpile and military buildings
- combat and enemy attacks
- deterministic enemy AI with staged opening pressure
- authoritative win/lose conditions
- population/supply cap
- compact HUD + command panel + debug overlay
- normalized definition-driven entity/stat schema

The main runnable scene is:

```bash
godot4 scenes/prototype_gameplay.tscn
```

## How To Verify

Use local Godot CLI, not only static inspection.

```bash
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --scene res://scenes/prototype_gameplay.tscn --quit-after 2

HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/gather_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/construction_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/combat_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/stone_prerequisite_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/ai_winlose_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/population_supply_test.gd
HOME=/tmp XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp godot4 --headless --script tests/entity_schema_test.gd
```

The recurring `get_system_ca_certificates` macOS warning is a Godot platform warning, not a project parse/load failure.

## Architectural Summary

Input and AI both create `SimulationCommand` objects only. `CommandBuffer` stores commands for execution at a stamped tick. `TickManager` advances the simulation at 10 Hz, collects AI commands for `current_tick + 1`, executes the current tick’s commands, runs systems in deterministic order, then records an authoritative state hash. `GameState` remains headless and authoritative. `ClientState`, `Renderer`, and `CommandPanel` only present state and gather input.

Flow:

```text
Input / AI
  -> SimulationCommand
  -> CommandBuffer (scheduled tick)
  -> TickManager.advance()
  -> Simulation systems mutate GameState
  -> State hash / replay data
  -> ClientState + Renderer + CommandPanel read-only presentation
```

## Critical Rules

1. Systems are the only place that mutate `GameState`.
2. Input/UI/AI produce commands or signals only, never direct simulation mutations.
3. Content values and default stats live in `simulation/game_definitions.gd`.
4. `GameState` must stay headless and client-independent.
5. Determinism depends on stable IDs, stable ordering, fixed tie-breaking, and tick-based execution.

## Current Gameplay Systems

### Economy
- Resources: `wood`, `stone`
- Workers gather, carry, return, deposit, and can be redirected without losing cargo
- Deterministic interaction slots for resource and stockpile approach
- Simple deterministic deadlock reduction in local worker traffic

### Buildings
- `stockpile` / base
- placeable `house`, `barracks`, `archery_range`
- prerequisite chain:
  - `house`
  - `barracks` requires `house`
  - `archery_range` requires `barracks`
- workers construct unfinished structures over authoritative ticks

### Production
- stockpile trains `worker`
- barracks trains `soldier`
- archery range trains `archer`
- deterministic spawn selection around producers
- blocked spawn state is surfaced in UI

### Population / Supply
- base population cap: `5`
- completed house: `+5` supply
- unit production uses reserved population gating, not just living count
- HUD/command panel now expose both current pop and queued/reserved pop where relevant

### Combat / Win-Lose
- soldiers and archers attack through `AttackCommand`
- enemy base destruction => win
- player stockpile destruction => lose
- overlay shows `You Win` / `You Lose`

### Enemy AI
- pure non-Node controller: `simulation/enemy_ai_controller.gd`
- uses same command pipeline as player
- deterministic staged opening:
  - delayed production start
  - delayed attack waves
  - minimum attackers before early aggression

## Normalized Entity / Stat Model

The project still uses authoritative `Dictionary` entities, but schema is now more normalized and definition-driven.

### Units
All units now normalize through `GameDefinitions.create_unit_entity(...)` / `normalize_entity(...)` and expose stable fields for:
- identity/type/owner
- movement state
- hp/max_hp
- attack state
- population cost
- worker cargo/task fields where relevant

Workers now have explicit HP and participate cleanly in the generic damage model.

### Structures / Buildings
Structures and stockpile now normalize through structure helpers and consistently expose:
- structure type / owner
- hp / max_hp
- construction state
- production state
- supply provided

### Resource Nodes
Resource nodes now normalize and expose:
- resource type
- remaining amount
- max amount
- gatherable flag
- depleted flag

This gives cleaner extension points for future armor, upgrades, vision, fog of war, or multiplayer serialization work without changing the dictionary-based architecture.

## Most Important Files

### Simulation foundation
- `simulation/game_definitions.gd`
- `simulation/game_state.gd`
- `runtime/tick_manager.gd`
- `runtime/command_buffer.gd`

### Simulation systems
- `simulation/systems/build_command_system.gd`
- `simulation/systems/gather_command_system.gd`
- `simulation/systems/movement_system.gd`
- `simulation/systems/worker_economy_system.gd`
- `simulation/systems/production_system.gd`
- `simulation/systems/combat_system.gd`
- `simulation/enemy_ai_controller.gd`

### Client / presentation
- `client/input_handler.gd`
- `client/command_panel.gd`
- `client/client_state.gd`
- `rendering/renderer.gd`
- `scenes/prototype_gameplay.gd`

## Current UX State

The normal UI now shows:
- resource totals
- population summary
- command-panel build/train buttons with disabled reasons
- clearer production progress and queue count
- clearer construction progress and builder state
- clearer bottleneck feedback such as:
  - missing wood
  - missing stone
  - need more houses
  - missing prerequisite
  - no builder assigned

## Current Known Limitations

1. No multiplayer / lockstep synchronization yet.
2. No replay playback UI or save/load yet.
3. No food/farms, tech tree, upgrades, or civ differentiation.
4. No fog of war yet.
5. No advanced building footprints or placement adjacency rules.
6. Enemy AI is intentionally simple and staged, not strategic.
7. Combat is functional but still fairly shallow.

## Best Next Architectural Questions

If an architect assistant is taking over, the most useful next design discussions are:

1. how to extend economy depth cleanly
2. how to deepen combat without breaking determinism
3. how to evolve the normalized entity schema for future upgrades/vision/fog
4. when to begin multiplayer/lockstep validation and serialization hardening

## Current Best Next Work

Recommended order:

1. deepen economy / production readability and throughput decisions further if needed
2. deepen combat and unit interaction depth
3. only after gameplay loop confidence is high, begin multiplayer/lockstep execution work
