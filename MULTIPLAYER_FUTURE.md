# Multiplayer Future Plan

## Model

- Lockstep simulation

## Concept

- Only validated commands are exchanged between peers
- All peers simulate same authoritative `GameState`
- Commands are scheduled for execution at tick `N`, never applied immediately

## Architecture Requirements

- Runtime owns fixed tick loop
- Runtime buffers commands by execution tick
- Simulation consumes commands only when target tick is reached
- Replay log and state hash verification exist before network layer
- AI already uses same command objects as player before multiplayer work starts

## Determinism Requirements

- Deterministic simulation
- Fixed tick rate
- No unsynchronized randomness
- Canonical entity IDs
- Stable iteration order
- Deterministic command ordering within tick
- Deterministic tie-breaking
- Integer or fixed-point authoritative positions

## Networking Later

- LAN first
- Transport can be Godot high-level multiplayer API or UDP
- Network layer must send commands and metadata, not state snapshots as primary model

## Important

Multiplayer is not implemented now.
Architecture must preserve lockstep path from day one.
