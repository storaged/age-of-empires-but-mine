# Handoff to Claude

Project: Age Of Empires But Mine
Engine: Godot 4.6.2
Language: GDScript
Current working directory: this repo root

## Current state
The game already has:
- deterministic tick-based simulation
- command pipeline
- replay/hash support
- selectable multiple workers
- grid movement
- obstacle blocking
- deterministic pathfinding
- worker gather/deposit loop
- deterministic local deadlock handling
- building placement prototype
- worker production prototype

## Important constraints
- Keep deterministic authoritative simulation intact
- Input must create commands only
- Rendering/client state must not mutate authoritative state
- Prefer simple robust RTS logic over clever abstractions
- Keep files lean
- Do not start broad new features until current playability issues are fixed

## Most recent real playtest findings
These are from actual Godot testing and should be treated as source of truth:
1. After the latest building/production phase, gather behavior regressed:
   - when trying to collect wood, workers did not move
2. Invalid actions are not clearly visible enough in the normal UI:
   - e.g. building with insufficient resources appears to do nothing
3. HUD/debug area is too crowded, so essential feedback gets lost

## Immediate task
Do a stabilization/playability pass only:
- fix gather regression
- add clear player-facing feedback for rejected actions
- reduce UI/debug clutter in always-visible HUD
- do not start the next broader feature phase

## Godot CLI
Godot is available locally as:
godot4

Use local verification, not only static code review.

## Required verification
Use local Godot CLI to verify parsing/loading, and check the gameplay scene.

## Expected output style
After changes, report:
1. exact root cause
2. exact files changed
3. exact gameplay/UI behavior after fixes
4. confirmation that no broader new phase was started
