# Age Of Empires But Mine

A deterministic RTS prototype built in Godot 4.6.2 / GDScript.

The simulation is authoritative, tick-based, and state-hashed — designed from the start to support future lockstep multiplayer without architectural changes.

## What It Is Right Now

A playable single-player RTS slice with:
- 4 starting workers gathering wood and stone
- Building prerequisite chain: House → Barracks → Archery Range
- Worker construction, soldier and archer training
- Attack commands against enemy units and an enemy base
- Context-sensitive command panel with clickable build/train buttons
- Enemy units on the map (currently passive — AI coming next)

## How To Run

Requires **Godot 4.6.2**.

```bash
# Open and run the prototype
godot4 scenes/prototype_gameplay.tscn

# Or open the project in the Godot editor
godot4 --editor
```

## Controls

| Input | Action |
|-------|--------|
| Left-click | Select unit or building |
| Drag left | Multi-select |
| Right-click ground | Move selected units |
| Right-click wood/stone node | Gather (workers) |
| Right-click your base | Return cargo (workers) |
| Right-click enemy | Attack (soldiers/archers) |
| Right-click construction site | Assign builder (workers) |
| **B** | Place House (30 wood) |
| **N** | Place Barracks (40 wood, requires House) |
| **M** | Place Archery Range (25 wood + 20 stone, requires Barracks) |
| Right-click (placement mode) | Place building |
| **ESC** | Cancel placement |
| **Q** | Train unit from selected building |
| WASD | Pan camera |
| Mouse wheel | Zoom |
| F3 or **DBG** button | Toggle debug overlay |

Build and train actions are also clickable in the command panel at the bottom of the screen. Buttons show cost and are disabled with a reason if prerequisites or resources are missing.

## What Is Implemented

- Deterministic tick-based simulation at 10 Hz
- Authoritative `GameState` with entity dictionary model
- Tick-stamped command pipeline with replay log and state hashing
- BFS deterministic pathfinding with occupancy avoidance
- Movement stall recovery (workers unblock from idle units)
- Two resource types: wood and stone
- Worker gather → carry → deposit loop for both resources
- Building placement with multi-resource cost validation
- Prerequisite chain: house required before barracks, barracks before archery range
- Worker construction assignment (right-click a construction site)
- Unit production queue: workers from stockpile, soldiers from barracks, archers from archery range
- Combat: soldiers and archers attack assigned targets, damage resolves per tick
- Enemy dummy units and destructible enemy base
- Context-sensitive command panel (selection detail + action buttons)
- Central content model (`game_definitions.gd`): adding a new building or unit only requires one dict entry
- 4 headless test suites

## Verification

```bash
godot4 --headless --script tests/gather_test.gd
godot4 --headless --script tests/construction_test.gd
godot4 --headless --script tests/combat_test.gd
godot4 --headless --script tests/stone_prerequisite_test.gd
```

All should print `*_TEST: PASS`.

## What Is Not Yet Implemented

- Enemy AI (units are passive; next priority)
- Win/lose condition (destroying enemy base removes it, no overlay)
- Population cap (houses built but not wired to a unit limit)
- Multiplayer / lockstep wiring (architecture ready, networking not started)

## Architecture Overview

```
Input → Commands → CommandBuffer → TickManager → Systems → GameState
                                                               ↓
                                               ClientState + Renderer (read-only)
```

`simulation/` is fully headless-testable. `client/` and `rendering/` only read state.
All content (costs, durations, render colors) is in `simulation/game_definitions.gd`.

See `ARCHITECTURE.md` for full detail and `HANDOFF_TO_CODEX.md` for contributor onboarding.
