# Determinism Rules

## Requirements

- Fixed timestep simulation
- No frame-dependent logic
- Use seeded RNG for randomness
- Commands execute only at stamped simulation ticks
- Replay and state hash verification must be supported from early stages

## Avoid

- Floating point authoritative movement
- Time-based updates (delta time)
- Unordered iteration over authoritative collections
- Hidden randomness outside deterministic RNG ownership
- Immediate command application outside runtime tick execution

## Goal

Running the same commands must always produce the same result.

## Concrete Constraints

- Every authoritative entity must have canonical deterministic ID
- Entity creation must use deterministic ID allocator
- Authoritative collections must use stable iteration order
- If dictionary-like storage is used, systems must sort keys before authoritative iteration
- Commands within same tick must execute in deterministic order
- Default command order: execution tick, player/issuer ID, command sequence number
- Ties in simulation resolution must use explicit deterministic tie-break rules
- Tie-breaks must never depend on scene tree order, object pointer identity, or frame timing
- Deterministic RNG state must live inside authoritative simulation state
- Systems may only use randomness through simulation-owned RNG
- Player, AI, rendering, and client feedback must not own separate authoritative randomness
- Authoritative positions must use integer grid coordinates or fixed-point representation
- Smooth movement may exist only as client-side interpolation over authoritative positions
- State hash must be computed from canonical authoritative state serialization
- Replay log must record tick-stamped commands needed to reproduce simulation
- Determinism verification must replay command log and compare state hashes at checkpoints

## Verification

- Runtime must support replaying same command stream from initial seed/state
- Runtime must expose state hash after selected ticks or every tick during testing
- Same replay input must produce same state hash sequence
- Determinism regressions must block further gameplay expansion
