# Handoff to Codex

Project: Age Of Empires But Mine  
Engine: Godot 4.6.2  
Language: GDScript  
Current phase: 31 (complete)

## What Exists Now

A deterministic RTS prototype with a real gameplay loop, pregame screen, and 20 headless regression tests passing.

Implemented systems:
- authoritative 10 Hz simulation
- tick-stamped command pipeline with replay/state hashing
- multi-unit selection and movement with BFS pathfinding + static blocker cache
- worker economy: wood, stone, food (farm passive income); full gather/deposit loop with interaction slot deconfliction
- building placement, construction, prerequisite chain (house → barracks → archery_range), and farm
- military production from barracks and archery_range
- population/supply cap
- combat with role-to-role damage multipliers (archer counters soldiers, etc.)
- attack-move command: soldiers hunt nearest in-range enemy while advancing
- producer rally points
- deterministic enemy AI with staged opening pressure (configurable per difficulty)
- authoritative win/lose conditions
- strategic timing HUD (stage, next goal, bottleneck, enemy wave countdown)
- food readiness analysis in HUD
- vision-gated rendering: enemy units/structures hidden when out of player vision
- last-seen enemy structure ghost rendering (client-side, dimmed, no HP)
- pregame difficulty screen (Easy/Normal/Hard) → `MatchConfig` → gameplay

The main runnable scene is `scenes/pregame.tscn` (set as project main scene).  
To bypass pregame and launch gameplay directly: `godot4 scenes/prototype_gameplay.tscn`

## How To Verify

```bash
# Parse check (no runtime):
godot4 --headless --quit --check-only

# Full 20-test suite (run from project root):
for t in gather construction combat stone_prerequisite ai_winlose population_supply \
  entity_schema strategic_timing rally congestion_recovery farm_food food_readiness \
  visibility production_readiness food_scaling combat_counter visibility_gating \
  worker_deposit_robustness attack_move interaction_slot; do
  godot4 --headless --script "tests/${t}_test.gd"
done
```

All 20 tests print `<NAME>_TEST: PASS`. The macOS `get_system_ca_certificates` warning is a Godot platform warning — not a project error.

## Core Architecture

### Simulation flow

```text
Input / AI
  -> SimulationCommand (tick-stamped, no direct state mutation)
  -> CommandBuffer
  -> TickManager.advance()        ← 10 Hz fixed step
  -> Systems mutate GameState     ← ONLY place mutation happens
  -> StateHasher / ReplayLog
  -> ClientState + Renderer + CommandPanel (read-only)
```

### Layer boundaries

| Layer | Location | Rule |
|-------|----------|------|
| Match config | `simulation/match_config.gd` | Headless RefCounted; passed pregame → gameplay |
| Content/stats | `simulation/game_definitions.gd` | All costs, durations, stats, multipliers, entity constructors |
| Authoritative state | `simulation/game_state.gd` | Data + typed helpers only; no simulation logic |
| Systems | `simulation/systems/` | Only place that mutates GameState |
| Commands | `commands/` | Intent objects; no state mutation |
| Runtime | `runtime/` | Tick loop, buffer, replay, hash |
| Client | `client/` | Input, selection, camera, command panel |
| Rendering | `rendering/` | Read-only draw |

### Critical traps for the next programmer

**1. `get_entity_dict()` returns a copy, not a reference.**  
`GameState.get_entity_dict(id)` calls `normalize_entity(entity.duplicate(true))` — it returns a new dict. You MUST write back: `game_state.entities[id] = entity` after modifying the returned dict. Forgetting this is the most common silent bug (changes discarded silently every tick).

**2. Any new unit field must be in `_normalize_unit_entity` whitelist.**  
`game_definitions.gd` → `_normalize_unit_entity()` is an explicit whitelist of all unit fields. Any field not listed there is stripped on every `get_entity_dict()` call. Add the field with its default before using it anywhere. This has bitten Phase 28 (`attack_move_target_cell` was stripped until added to whitelist).

**3. Static methods inside a class can't use their own `class_name` as a return type.**  
GDScript can't resolve the `class_name` at parse time when it's in the same file. Use `RefCounted` as the return type on factory/static methods, or move factories outside the class.

**4. AI timing constants are public for test/display, instance vars for actual behavior.**  
`EnemyAIController` has public `const ATTACK_START_TICK`, etc. (for `strategic_timing.gd` and tests), AND private instance vars `_attack_start_tick`, etc. (used at runtime). `configure(MatchConfig)` sets the instance vars. Don't confuse them.

## Match Configuration Flow

```text
pregame.tscn  (main scene, project.godot)
  user picks Easy/Normal/Hard
  builds MatchConfig (colors, AI timing; Normal = default field values)
  loads prototype_gameplay.tscn, calls set_match_config(cfg)

prototype_gameplay._ready()
  if _match_config == null: uses MatchConfig defaults  ← safe direct launch
  enemy_ai_controller.configure(_match_config)
  renderer.configure(game_state, client_state, CELL_SIZE, _match_config)
```

## System Execution Order Per Tick

1. BuildCommandSystem
2. MoveCommandSystem
3. GatherCommandSystem
4. CombatSystem
5. MovementSystem
6. WorkerEconomySystem
7. StructureEconomySystem
8. ProductionSystem

## Movement Priority Table

In `movement_system.gd` `TRAFFIC_PRIORITY_BY_TASK` (lower = higher priority):

| 0 | depositing |
| 1 | to_stockpile |
| 2 | gathering |
| 3 | to_resource, to_construction, to_target, attack_moving |
| 4 | to_rally, idle |

## Entity Schema (unit)

All unit fields that survive `normalize_entity()`:

```
id, entity_type, unit_role, owner_id
grid_position, move_target, path_cells, has_move_target
worker_task_state, interaction_slot_cell, traffic_state, movement_wait_ticks
hp, max_hp
attack_target_id, attack_cooldown_remaining, attack_damage, attack_cooldown_ticks, attack_range_cells
attack_move_target_cell      ← (-1,-1) when not attack-moving; MUST be in whitelist
population_cost, vision_radius_cells, can_attack, carry_capacity
assigned_resource_node_id, assigned_stockpile_id, assigned_construction_site_id
carried_resource_type, carried_amount
harvest_amount, gather_duration_ticks, deposit_duration_ticks, gather_progress_ticks
```

## Key Files

### Must read before changing anything

- `simulation/game_definitions.gd` — all content, `_normalize_unit_entity` whitelist
- `simulation/game_state.gd` — entity access pattern, interaction slot logic, static blocker cache
- `simulation/systems/worker_economy_system.gd` — write-back pattern (the most fragile system)
- `simulation/systems/combat_system.gd` — attack-move and attack logic

### Useful to understand before adding features

- `simulation/enemy_ai_controller.gd` — configure() + const/var distinction
- `simulation/match_config.gd` — what's configurable at match start
- `simulation/strategic_timing.gd` — HUD timing logic, reads AI consts
- `rendering/renderer.gd` — visibility gating, ghost structures, configure() signature
- `scenes/prototype_gameplay.gd` — wires everything together, set_match_config()

## Current Economy

Resources: `wood`, `stone`, `food`

- Workers gather wood and stone from nodes
- Farms produce food passively each tick (via StructureEconomySystem)
- Military unit training costs food
- Stockpile rally → workers auto-gather after training

## Current Buildings

| Building | Cost | Requires | Produces |
|----------|------|----------|---------|
| house | 30 wood | — | +5 pop cap |
| farm | 40 wood | — | food income |
| barracks | 50 wood, 20 stone | house | soldier |
| archery_range | 60 wood, 30 stone | barracks | archer |

## Current Units

| Unit | Role | Notes |
|------|------|-------|
| worker | worker | gathers, builds, deposits |
| soldier | soldier | melee; +50% vs workers |
| archer | archer | ranged (attack_range_cells=3); +50% vs soldiers |
| enemy_dummy | soldier | enemy unit type |

## Current Known Limitations

1. No multiplayer / lockstep synchronization.
2. No replay playback UI or save/load.
3. No tech tree or upgrades.
4. No authoritative fog of war (only visibility-gated rendering).
5. No advanced building footprints or placement adjacency rules.
6. Enemy AI is staged/scripted, not strategic or reactive to player composition.
7. Map layout is hardcoded in `prototype_gameplay._create_initial_game_state()` — not yet driven by MatchConfig.
8. Pregame difficulty changes AI timing only; colors are wired but all three difficulties use the same default colors (Easy/Hard color schemes not differentiated yet).

## Best Next Work

**Option A — Map / Scenario Variety** (natural Phase 31 extension)  
Move the blocked-cell layout, resource positions, and starting unit positions into `MatchConfig`. Add a second map selectable in pregame. Medium scope, high payoff for replayability.

**Option B — Smarter Enemy AI**  
AI currently only produces attackers. Make it build farms, houses, and react to the player army composition. Stays within the non-Node command-pipeline architecture.

**Option C — Deeper Tech Tree**  
Extend the prerequisite system for a second-tier unit (knight, crossbow) or building upgrades. All costs/gates stay in `game_definitions.gd`.

**Option D — Replay Playback UI**  
`ReplayLog` already captures all commands. Wire a headless replay runner that re-executes the log and verifies the state hash sequence.

**Option E — Multiplayer / Lockstep**  
Harden `GameState` serialization, add two-client lockstep validation with hash comparison. Only after gameplay is stable.
