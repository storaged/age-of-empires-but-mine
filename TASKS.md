# Development Tasks

## Completed

### Phase 1 — Deterministic Core
- Godot project scaffold
- authoritative `GameState`
- fixed-step `TickManager`
- tick-stamped `CommandBuffer`
- replay log and authoritative state hashing
- smoke-test scene

### Phase 2 — First Playable Slice
- 2D top-down prototype scene
- deterministic grid-backed movement
- unit selection and move orders
- client-side interpolation over authoritative movement
- compact HUD and debug overlay

### Phase 3 — Multi-Unit Control
- multiple controllable units
- marquee box selection
- deterministic multi-unit move assignment

### Phase 4 — Obstacles And Occupancy
- blocked terrain cells
- obstacle rendering
- deterministic occupancy checks
- move rejection on invalid cells

### Phase 5 — Deterministic Pathfinding
- authoritative BFS pathfinding
- deterministic neighbor/tie behavior
- path-based movement through obstacles

### Phase 6 — Worker Economy Slice
- workers, resource nodes, stockpile
- gather command and authoritative gather/deposit loop
- carried cargo state
- HUD resource totals

### Phase 7 — Worker Economy Robustness
- explicit return-cargo flow
- deterministic resource/stockpile interaction slots
- better worker deposit usability

### Phase 8 — Traffic / Deadlock Resolution
- deterministic local traffic priority
- simple swap/vacate handling
- reduced obvious worker deadlocks

### Phase 9 — Building Placement / Construction / Production
- house, barracks, archery range placement
- worker construction over simulation ticks
- stockpile and military building production
- deterministic spawn selection

### Phase 10 — Multi-Resource / Combat / Command UI
- stone resource and stone gathering
- prerequisite chain: `house -> barracks -> archery_range`
- soldier and archer combat units
- enemy structures/targets
- context-sensitive command panel
- build/train buttons with readable disabled reasons

### Phase 11 — Enemy AI And Win/Lose
- deterministic non-Node enemy AI controller
- AI issues real authoritative commands
- staged enemy production and attack pressure
- player stockpile HP
- authoritative win when enemy base dies
- authoritative lose when player stockpile dies
- gameplay overlay for `You Win` / `You Lose`

### Phase 12 — Population / Supply
- authoritative population cap / supply system
- baseline supply cap
- houses increase available supply
- unit production consumes population room
- production rejects at cap
- HUD and command panel show population

### Phase 13 — Economy / Production Readability
- clearer production queue visibility
- clearer training/construction progress in normal UI
- readable living vs queued/reserved population summary
- clearer bottleneck feedback

### Phase 14 — Authoritative Entity / Stat Normalization
- normalized definition-driven unit defaults
- normalized structure / stockpile defaults
- normalized resource node defaults
- workers now fit generic damageability model

### Phase 15 — Strategic Timing / Development Race Readability
- deterministic strategic timing summary based on authoritative state
- clear player stage framing (stabilize / scale / pressure / pressure ready)
- normal HUD shows current stage, timing status, next goal, bottleneck, enemy countdown
- new strategic timing regression test

### Phase 16 — Definition-Driven Combat Role Depth
- normalized `attack_range_cells` in unit definitions
- archers now fight as real ranged units
- selected combat units show attack stats and visible range feedback
- enemy production selection follows producer/unit definitions

### Phase 17 — Producer Rally / Throughput / Readiness
- authoritative producer rally state
- right-click with selected producer sets rally
- stockpile can rally workers directly into gather loop
- spawned units inherit deterministic post-spawn rally behavior

### Phase 18 — Congestion Recovery / Fair Opening Pacing
- bounded deterministic congestion recovery (repath after wait threshold)
- early enemy pressure retuned for fair opening

### Phase 19 — Food / Farms Economy Planning
- authoritative `food` resource
- placeable `farm` building with passive food income
- military production consumes food
- strategic timing surfaces `Build Farm` goal

### Phase 20 — Food Readiness / Scaling Depth
- food-readiness analysis vs military production demand
- `Add Farm` timing guidance when food flow is thin
- food ETA feedback when food is the bottleneck

### Phase 21 — Combat Counters / Tactical Readability
- definition-driven role-to-role damage multiplier table
- archer counters soldiers (+50%), workers (+25%); soldier counters workers (+50%), archers (+25%)
- counter labels shown in command panel

### Phase 22 — Food Scaling Throughput / Performance Sanity
- static blocker cache on `GameState` — O(1) cell lookup for pathfinding (was O(entities))
- food surplus detection: `can_sustain_another_producer` guides barracks expansion
- `per_producer_demand` and `military_producer_count` in food summary

### Phase 23 — Production / Readiness Depth
- army pipeline readiness (deployed / ready / assembling)
- production batch ETA for queued units
- generic bottleneck detection works for archery_range

### Phase 24 — Vision / Information Groundwork
- `vision_radius_cells` on all unit and building definitions
- `simulation/visibility.gd` — pure read-side visibility computation
- Manhattan distance model, map-boundary clamped
- command panel shows vision radius and enemy intel count

### Phase 25 — Minimal Visibility-Gated Presentation
- enemy units/structures hidden when not in player visible cells
- `_player_visible_cells` computed once per `_draw()` frame

### Phase 26 — Last-Seen Enemy Structure Memory
- `_seen_enemy_structures` dict on renderer (client-side only)
- previously-seen-but-not-visible enemy structures rendered as dimmed ghosts (no HP bar)
- destroyed structures disappear naturally from ghost view

### Phase 27 — Worker Deposit / Interaction Robustness
- fixed silent write-back bug: `_reassign_*slot` results were discarded every tick
- adjacent-position fast path: worker already next to target adopts current cell as slot
- nearest-first fallback: `_assign_path_to_slot` tries closest alternatives before going idle

### Phase 28 — Attack-Move / Basic Army Command Feel
- `commands/attack_move_command.gd` — new command type
- `attack_move_target_cell` added to unit entity schema (normalized field)
- combat units issue `AttackMoveCommand` on right-click ground
- soldiers hunt nearest in-range enemy while advancing; resume after combat; arrive and idle

### Phase 29 — Deterministic Local Access / Egress Robustness for Workers
- `get_interaction_slot_for_worker` rewritten with greedy nearest-first deconfliction
- workers claim nearest unclaimed slot in sorted entity-id order — position-aware, no crossing
- new helpers: `_raw_entity_grid_position`, `_nearest_unclaimed_slot`, `_slot_before`

### Phase 30 — Readability + Local Recovery Polish
- `attack_moving` added to `TRAFFIC_PRIORITY_BY_TASK` at priority 3
- player soldiers: blue `#4a7fc1`; enemy units: orange-red `#e84a1e`; enemy structures: `#c93a1a`

### Phase 31 — Config-Driven Match Setup / Pregame Screen
- `simulation/match_config.gd` — headless `RefCounted` config: faction colors, AI timing, map dims; clean Normal defaults
- `scenes/pregame.gd` + `pregame.tscn` — main scene; Easy/Normal/Hard difficulty selector builds `MatchConfig` and passes it to gameplay
- `enemy_ai_controller.configure(cfg)` — AI timing now driven by instance vars; public consts kept for tests and strategic_timing HUD display
- `renderer.configure(…, cfg)` — applies faction color overrides from config
- `prototype_gameplay.set_match_config(cfg)` — receives config; falls back to Normal defaults if launched directly

## Current Regression Coverage (20 tests)

```bash
godot4 --headless --script tests/gather_test.gd
godot4 --headless --script tests/construction_test.gd
godot4 --headless --script tests/combat_test.gd
godot4 --headless --script tests/stone_prerequisite_test.gd
godot4 --headless --script tests/ai_winlose_test.gd
godot4 --headless --script tests/population_supply_test.gd
godot4 --headless --script tests/entity_schema_test.gd
godot4 --headless --script tests/strategic_timing_test.gd
godot4 --headless --script tests/rally_test.gd
godot4 --headless --script tests/congestion_recovery_test.gd
godot4 --headless --script tests/farm_food_test.gd
godot4 --headless --script tests/food_readiness_test.gd
godot4 --headless --script tests/visibility_test.gd
godot4 --headless --script tests/production_readiness_test.gd
godot4 --headless --script tests/food_scaling_test.gd
godot4 --headless --script tests/combat_counter_test.gd
godot4 --headless --script tests/visibility_gating_test.gd
godot4 --headless --script tests/worker_deposit_robustness_test.gd
godot4 --headless --script tests/attack_move_test.gd
godot4 --headless --script tests/interaction_slot_test.gd
```

## Best Next Work

### Option A — Map / Scenario Variety
- pass map layout (blocked cells, resource positions, starting units) through `MatchConfig`
- add a second map or procedural blocked-cell variation selectable in pregame
- keeps pregame screen useful and extensible

### Option B — Deeper Economy / Tech Tree
- stone-gated buildings or unit upgrades via definition-driven prerequisite extension
- add a second-tier military unit (knight, crossbow, siege)
- all costs/durations stay in `game_definitions.gd`

### Option C — Smarter Enemy AI
- AI selects unit composition based on player army composition
- AI builds economy structures (farms, houses) instead of only military
- AI uses attack-move command instead of raw attack
- stays within the same non-Node command-pipeline architecture

### Option D — Replay Playback UI
- `ReplayLog` already records all commands
- add a headless replay runner that re-executes log and snapshots per-tick state
- verify state hash sequence matches original session

### Option E — Multiplayer / Lockstep Foundation
- only after gameplay shape stabilizes further
- serialization hardening of `GameState` (all fields explicit, no implicit defaults)
- lockstep validation: two local clients, same command stream, hash comparison

## Not Started Yet

- multiplayer / lockstep synchronization
- replay playback UI
- save / load
- upgrades / tech tree
- fog of war (authoritative shroud, not just visibility gating)
- advanced building footprints
- broad AI strategy layer
- formation / squad behavior
- second map or map selection

## Rules

- keep changes incremental and runnable
- preserve deterministic authoritative boundaries
- input and AI must issue commands only
- systems are the only place that mutate `GameState`
- content values and default stats belong in `simulation/game_definitions.gd`
- any new unit field must be added to `_normalize_unit_entity` in `game_definitions.gd`
- prefer coherent vertical slices over broad placeholder architecture
