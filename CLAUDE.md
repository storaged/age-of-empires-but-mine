# Claude instructions for this repository

Project: Age Of Empires But Mine  
Engine: Godot 4.6.2  
Language: GDScript

## Core architecture rules
- Preserve deterministic authoritative simulation
- Input must create commands only
- Client/rendering must not mutate authoritative simulation state
- Rendering reads state only
- Keep simulation, runtime, client, and rendering responsibilities separated
- Prefer simple, robust RTS logic over clever abstractions
- Keep files lean
- Do not broaden scope without necessity

## Current project state
The project already has:
- deterministic tick-based simulation
- command pipeline
- replay/hash support
- multi-unit selection
- obstacle blocking
- deterministic pathfinding
- worker gather/deposit loop
- deterministic local deadlock handling
- building placement prototype
- worker production prototype

## Current known issues from real playtesting
Treat actual Godot testing as source of truth.

Immediate priority:
1. Fix the gather regression where workers do not move to collect wood
2. Add clear player-facing feedback in the normal HUD/UI for rejected actions:
   - not enough wood
   - invalid placement
   - invalid gather
3. Reduce always-visible HUD clutter so important feedback is readable

## Verification rules
- Use local Godot CLI: `godot4`
- Do not rely only on static code inspection
- Verify parsing/loading after changes
- Prefer concrete validation over assumptions

## Working style
- Before editing, summarize:
  1. current architecture
  2. current known issues
  3. exact files to inspect first
- After editing, report:
  1. root cause
  2. files changed
  3. verification commands used
  4. resulting behavior
  5. confirmation that no broader phase was started

## Scope discipline
- Do stabilization/playability work first
- Do not start broader new gameplay phases until current issues are fixed