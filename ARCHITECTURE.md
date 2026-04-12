# Architecture

## Core Principle

Game must be deterministic, tick-driven, and state-driven.

Flow:
Input/AI -> CommandBuffer (tick-stamped) -> SimulationStep -> StateHash/ReplayLog -> Rendering

## Separation of Concerns

- `simulation/`: authoritative state and simulation systems only
- `commands/`: validated player and AI command objects
- `runtime/`: tick loop, command buffer/queue, replay log, state hash verification
- `client/`: input translation, camera, selection, hover, indicators
- `rendering/`: visual sync from simulation state and client state

## Data Ownership

- `GameState` stores authoritative simulation data only
- `GameState` contains no simulation logic
- Entity data is plain simulation data, not behavior-heavy objects
- Systems are only place where simulation rules mutate `GameState`
- Client state stores presentation-only state
- Rendering reads simulation state and client state, but mutates neither directly

## GameState Includes

- Canonical entity IDs
- Map and terrain data needed by simulation
- Grid occupancy
- Unit and building state
- Resources
- Production queues
- Deterministic RNG state

## GameState Excludes

- Camera position
- Selection state
- Hover state
- Command indicators
- Scene tree node references
- Animation or interpolation state

## Runtime Responsibilities

- Advance fixed simulation ticks
- Accept commands for execution at tick `N`
- Buffer and order commands deterministically
- Execute simulation step for one tick
- Record replay data
- Compute and verify state hash after simulation steps

## Command Model

- Player input becomes validated command objects
- AI issues exact same command objects as player
- Commands are intent only, never direct state mutation
- Commands must be stamped with execution tick
- Commands execute only when runtime reaches stamped tick

## Folder Structure

simulation/
  game_state.gd
  deterministic_pathfinder.gd
  systems/
    debug_command_system.gd
    move_command_system.gd
    movement_system.gd
    gather_command_system.gd
    worker_economy_system.gd

commands/
  command.gd
  move_unit_command.gd
  gather_resource_command.gd

runtime/
  tick_manager.gd
  command_buffer.gd
  replay_log.gd
  state_hasher.gd

client/
  input_handler.gd
  client_state.gd

rendering/
  renderer.gd

scenes/
  prototype_gameplay.tscn
  smoke_test.tscn

## Current Vertical Slice

- Multiple selectable player-controlled units
- Deterministic move commands
- Authoritative blocked terrain and occupancy discipline
- Deterministic pathfinding on the simulation grid
- Worker-resource-stockpile loop on the authoritative simulation side
- Client-side interpolation layered over authoritative tick movement
- Clean prototype HUD with economy totals and optional debug overlay

## Next Slice

- Expand the economy only where the current slice shows a real need
- Keep reusing authoritative pathfinding and occupancy rules
- Preserve the same command/runtime/client/rendering boundaries

## Rules

- Systems are only place that mutate `GameState`
- No simulation logic inside `GameState`
- No simulation logic inside rendering
- No direct input -> state mutation
- No direct AI -> state mutation
- Client state must never be required for authoritative simulation
- Authoritative movement uses integer or fixed-point grid-backed positions
- Smooth movement, hover, and indicators stay client-side only
