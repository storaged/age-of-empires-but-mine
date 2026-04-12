# Development Tasks

## Completed

### Phase 1 — Deterministic Core

- Created Godot project scaffold
- Implemented authoritative `GameState`
- Implemented fixed-step `TickManager`
- Implemented tick-stamped `CommandBuffer`
- Implemented replay log and authoritative state hashing
- Added deterministic smoke test scene

### Phase 2 — First Playable Slice

- Added top-down 2D prototype scene
- Added grid-backed map rendering
- Added controllable units
- Added click selection and move commands
- Added client-side interpolation over authoritative tick movement
- Added clean HUD plus `F3` debug overlay

### Phase 3 — Multi-Unit Control

- Added multiple controllable units
- Added marquee selection
- Added deterministic group destination assignment
- Preserved single-click selection and single move pipeline

### Phase 4 — Obstacles And Occupancy

- Added authoritative blocked cells
- Rendered obstacles in prototype
- Rejected blocked move targets
- Added deterministic occupancy reservation by stable unit order

### Phase 5 — Deterministic Pathfinding

- Added deterministic grid pathfinding
- Routed move commands through authoritative path generation
- Preserved occupancy waiting behavior
- Stabilized project for Godot 4.6 strict parsing / strict typing baseline

### Phase 6 — Worker Economy Slice

- Added worker-role units
- Added resource nodes
- Added one stockpile / base structure
- Added gather command through the existing tick-stamped command pipeline
- Implemented deterministic worker gather -> return -> deposit loop
- Added HUD resource totals and selected worker task summary

## Next Phase

### Phase 7 — Expand Economy Carefully

- Tighten worker task feedback only where the current slice is unclear
- Add more resource clusters only if the map needs them for testing
- Add a second resource type only if the command/simulation model stays lean
- Add the minimum construction prerequisite needed to grow economy

### Phase 8 — Combat Slice

- Add one combat unit type
- Add attack command and target acquisition rules
- Add deterministic hit / damage resolution

### Phase 9 — Production Slice

- Add one production building
- Add basic unit training queue
- Route production through same authoritative tick model

### Phase 10 — AI And Multiplayer Prep

- Add simple AI issuing same command objects as player
- Strengthen replay verification scenarios
- Prepare lockstep validation hooks and desync diagnostics

## Rules

- Keep work incremental and runnable
- Preserve deterministic simulation boundary
- Commands remain intent only
- Systems remain the only place that mutate authoritative simulation state
- Client feedback may be immediate, but must stay outside `GameState`
- Prefer lean vertical slices over broad placeholder systems
