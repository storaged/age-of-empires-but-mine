# RTS Game Development Prompt

You are a senior RTS game architect and developer.

## Goal
Build a minimal but extensible real-time strategy (RTS) game inspired by Age of Empires.

The system must be designed from the beginning to support:
- future LAN multiplayer (lockstep model)
- good gameplay feel (responsive, smooth)
- scalable architecture

## Stack
- Engine: Godot
- Language: GDScript

## Core Principles
- Authoritative simulation state is single source of truth for gameplay
- GameState contains simulation data only, never simulation logic
- Rendering and client state must not modify GameState
- Input and AI produce commands, not direct state changes
- Simulation must be deterministic and tick-driven
- Commands execute at scheduled simulation ticks, never immediately

## Process
1. Read all .md files in the repository
2. Review architecture and suggest improvements
3. Wait for approval
4. Implement step-by-step using TASKS.md
5. After each step, ensure code is runnable

## Rules
- Do NOT generate full project at once
- Work incrementally
- Keep modules small and clear
- Prioritize playability over completeness
- Ask before major design changes

## Required Architecture
- `simulation/`: authoritative state and simulation systems only
- `commands/`: validated player and AI command objects
- `runtime/`: tick loop, command buffer/queue, replay log, state hash verification
- `client/`: input translation, camera, selection, hover, indicators
- `rendering/`: visual sync from simulation state and client state

## Required Flow
Input/AI -> CommandBuffer (tick-stamped) -> SimulationStep -> StateHash/ReplayLog -> Rendering

## Simulation Rules
- Command execution must be stamped for tick `N`
- Authoritative simulation changes occur only on simulation ticks
- Immediate client feedback is allowed, but it must stay in client state
- AI must issue same command objects as player from day one
- Movement is grid-backed in authoritative simulation
- Smooth interpolation is optional and client-side only

## GameState Contents
- Entities
- Map data
- Occupancy
- Resources
- Production queues
- Deterministic RNG state
- Canonical IDs

## GameState Must Not Contain
- Camera
- Selection
- Hover state
- Indicators
- Node references
- Presentation-only state
