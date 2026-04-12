# Handoff to Codex

Project: Age Of Empires But Mine
Engine: Godot 4.6.2
Language: GDScript
Repo: storaged/age-of-empires-but-mine

## What This Is

A deterministic RTS prototype built around an authoritative tick-based simulation. All game logic runs in a fixed-step simulation at 10 Hz; rendering reads state but never mutates it. The architecture is designed to support future lockstep multiplayer via state hashing and replay logs.

## How To Run

```bash
# Run the prototype scene
godot4 scenes/prototype_gameplay.tscn

# Parse-check a file (no window)
godot4 --headless --check-only --script path/to/file.gd

# Run headless tests
godot4 --headless --script tests/gather_test.gd
godot4 --headless --script tests/construction_test.gd
godot4 --headless --script tests/combat_test.gd
godot4 --headless --script tests/stone_prerequisite_test.gd
```

All 4 test suites currently pass. Run them after every change to simulation logic.

## Architecture In One Paragraph

Input translates to `SimulationCommand` objects. Commands are buffered (tick-stamped) in `CommandBuffer`. `TickManager` advances the simulation at 10 Hz, executing commands at their stamped tick, running all `SimulationSystem` subclasses in order, then hashing the resulting `GameState`. `Renderer` and `CommandPanel` read state but never write it. `ClientState` holds camera/selection/hover — it is entirely separate from simulation state.

## Critical Rules — Do Not Violate

1. **Systems only mutate GameState.** Never mutate GameState from input handlers, renderer, or command panel.
2. **Input produces commands, not mutations.** `input_handler.gd` and `command_panel.gd` emit signals or return `SimulationCommand` objects.
3. **All content lives in `game_definitions.gd`.** Costs, durations, render colors, spawn templates. Never hardcode these elsewhere.
4. **Commands are intent only.** They carry parameters (unit ID, target cell, etc.) but never execute logic.
5. **Client state is never required by simulation.** `GameState` + systems must be runnable headlessly.

## Current Implemented Systems

### Entities
All entities are plain `Dictionary` in `game_state.entities`. Types: `unit`, `structure`, `stockpile`, `resource_node`.

### Resources
- Two types: `wood`, `stone`
- Stored in `game_state.resources: {"wood": int, "stone": int}`
- Workers gather from resource nodes and deposit at stockpile

### Building Chain
```
house (30W) → barracks (40W) → archery_range (25W 20S)
```
- Each requires the previous to be **fully constructed** first
- Workers build by being assigned via right-click on construction site
- `is_prerequisite_met(building_type)` on GameState checks for completed structure

### Unit Roster
| Unit | Trains From | Cost | Role |
|------|-------------|------|------|
| Worker | Stockpile | 20W | gather, construct |
| Soldier | Barracks | 20W | attack |
| Archer | Archery Range | 15W 10S | attack |

### Production
- `QueueProductionCommand(tick, player_id, seq, producer_id, unit_type)` queues training
- `ProductionSystem` ticks progress, spawns unit adjacent to building when complete
- `game_state.can_afford_production(unit_type)` + `deduct_production_cost()` for resource checks

### Combat
- Soldiers and archers auto-attack targets assigned via `AttackCommand`
- `CombatSystem` resolves damage each tick, removes dead entities
- Enemy dummy units and enemy base exist on the map (static, attackable)

### Pathfinding
- `DeterministicPathfinder.find_path(from, to, blocked_cells, occupied_cells, avoid_occupied: bool)`
- BFS, fully deterministic
- `avoid_occupied=true` for combat/gather approach; `avoid_occupied=false` for move-to

### Movement Stall Recovery
- `MovementSystem` detects when a unit is "waiting" behind a truly idle blocker
- Clears the path → forces re-plan next tick with `avoid_occupied=true`

### Command Panel
- `client/command_panel.gd` — 130px bottom panel
- Left side: `RichTextLabel` with selection detail (live status, HP, task, construction progress)
- Right side: up to 8 `Button` slots (4×2 grid), context-sensitive
- DBG button far right; also F3 key
- Signals handled by `prototype_gameplay.gd`

## Controls

| Input | Action |
|-------|--------|
| Left-click | Select unit/building |
| Drag left | Multi-select box |
| Right-click ground | Move selected units |
| Right-click resource node | Gather (workers) |
| Right-click stockpile | Return cargo (workers) |
| Right-click enemy | Attack (soldiers/archers) |
| Right-click construction site | Assign builder (workers) |
| B | Begin house placement |
| N | Begin barracks placement |
| M | Begin archery range placement |
| Right-click (in placement mode) | Place building |
| ESC | Cancel placement |
| Q | Train unit from selected building |
| WASD | Camera pan |
| Mouse wheel | Zoom |
| F3 or DBG button | Toggle debug overlay |

Command panel build/train buttons are the primary UI; hotkeys are shortcuts.

## GameDefinitions API (most important methods)

```gdscript
GameDefinitions.get_building_costs("archery_range")          # → {"wood": 25, "stone": 20}
GameDefinitions.get_building_prerequisite("barracks")         # → "house"
GameDefinitions.get_building_produces("barracks")             # → "soldier"
GameDefinitions.get_building_render_colors("barracks")        # → {"base": Color, "inner": Color, "border": Color}
GameDefinitions.get_unit_production_costs("archer")           # → {"wood": 15, "stone": 10}
GameDefinitions.format_costs(costs_dict)                      # → "15 wood, 10 stone"
GameDefinitions.format_costs_short(costs_dict)                # → "15W 10S"
GameDefinitions.create_unit_entity(type, id, owner, cell, producer_id)  # → ready entity dict
GameDefinitions.is_known_building_type("barracks")            # → true
```

## GameState API (most important helpers)

```gdscript
game_state.can_afford_building("house")         # bool
game_state.deduct_building_cost("house")        # mutates resources
game_state.refund_building_cost("house")        # mutates resources
game_state.can_afford_production("worker")      # bool
game_state.deduct_production_cost("worker")     # mutates resources
game_state.is_prerequisite_met("barracks")      # scans entities for completed house
game_state.get_entity_can_attack(entity)        # bool, checks attack_target_id field
game_state.get_resource_amount("wood")          # int
game_state.allocate_entity_id()                 # → next int ID
```

## Current Known Limitations

1. **No enemy AI.** Enemy units and base exist but are static/passive — they don't move or attack.
2. **No win/lose condition.** Destroying the enemy base causes entity removal but no game-over screen.
3. **No lose condition.** Player stockpile has no HP.
4. **Single player only.** Multiplayer lockstep not yet wired, though architecture supports it.
5. **Production queue capped at 1.** Only one unit trains at a time per building; queue count stored but not stacked.
6. **No unit limit.** Houses built but not wired to a population cap mechanic.
7. **Placement preview cost display** in status_label uses `get_building_cost` (wood-only shorthand); for multi-resource buildings the cost in the top HUD label is incomplete. The command panel buttons show full costs correctly.

## Recommended Next Phase: Enemy AI And Win Condition

This is the most impactful next step. The simulation is deterministic and all necessary command types exist.

**Scope:**
1. Add an `AIController` (non-Node, pure logic, called by `TickManager` or `prototype_gameplay.gd` each tick)
2. AI issues real `SimulationCommand` objects (same as player) — `QueueProductionCommand`, `AttackCommand`
3. Enemy soldiers pathfind toward and attack player stockpile (add HP to stockpile)
4. Add `win_condition_met: bool` and `lose_condition_met: bool` to `GameState`
5. `CombatSystem` sets these flags when enemy base or player stockpile HP reaches 0
6. Simple overlay in `prototype_gameplay.gd` for "You Win" / "You Lose"

**Do not:**
- Add multiplayer wiring yet
- Add unit caps / population yet (needs house mechanic)
- Add tech trees or new building types

## File Checklist For New Agents

Before modifying simulation logic, read:
- `simulation/game_definitions.gd` — content model
- `simulation/game_state.gd` — entity helpers and resource helpers
- The relevant system in `simulation/systems/`

Before modifying UI, read:
- `client/command_panel.gd` — panel signals and refresh flow
- `client/input_handler.gd` — how commands are built from input
- `scenes/prototype_gameplay.gd` — signal handlers and game loop

After any simulation change:
```bash
godot4 --headless --check-only --script [changed_file.gd]
godot4 --headless --script tests/gather_test.gd
godot4 --headless --script tests/construction_test.gd
godot4 --headless --script tests/combat_test.gd
godot4 --headless --script tests/stone_prerequisite_test.gd
```
