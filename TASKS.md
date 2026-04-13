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
- clearer bottleneck feedback:
  - missing wood
  - missing stone
  - need more houses
  - missing prerequisite
  - no builder assigned

### Phase 14 — Authoritative Entity / Stat Normalization
- normalized definition-driven unit defaults
- normalized structure / stockpile defaults
- normalized resource node defaults
- workers now fit generic damageability model
- cleaner foundation for future armor/upgrades/vision/fog

### Phase 15 — Strategic Timing / Development Race Readability
- deterministic strategic timing summary based on authoritative state
- clear player stage framing:
  - stabilize
  - scale
  - pressure
  - pressure ready
- normal HUD now shows:
  - current stage
  - timing status
  - next strategic goal
  - current bottleneck
  - enemy pressure countdown
- empty-selection command panel now acts as a strategic overview panel
- new strategic timing regression test

### Phase 16 — Definition-Driven Combat Role Depth
- normalized `attack_range_cells` in unit definitions
- generic combat flow now supports melee and ranged units through stats, not adjacency-only assumptions
- archers now fight as real ranged units instead of pseudo-melee attackers
- selected combat units now show attack stats and visible range feedback
- enemy production selection now follows producer/unit definitions instead of hardcoded `barracks -> soldier`
- new regression coverage for ranged combat and generic enemy combat production

### Phase 17 — Producer Rally / Throughput / Readiness
- authoritative producer rally state:
  - `rally_mode`
  - `rally_cell`
  - `rally_target_id`
- right-click with a selected producer now sets rally:
  - ground rally for any producer
  - resource rally for worker producers
- stockpile can rally newly produced workers directly into the gather loop
- spawned units now inherit deterministic post-spawn rally behavior
- producer summaries now show rally state and rally instructions
- selected producers render visible rally feedback in the world
- strategic timing bottlenecks now surface blocked production / queued reinforcements more clearly
- queue validation now enforces producer output from definitions
- new rally regression coverage for:
  - worker resource rally
  - cell rally improving tight spawn throughput

### Phase 18 — Congestion Recovery / Fair Opening Pacing
- bounded deterministic congestion recovery for units stalled in local lines
- units now repath only after a fixed authoritative wait threshold instead of stalling indefinitely
- movement recovery keeps the same authoritative target and avoids uncontrolled pathfinding spam
- early enemy pressure retuned to give the player time to gather, build, produce, and respond
- later first production and first attack thresholds
- slower early wave cadence
- higher minimum attacker count before pressure starts
- new congestion recovery regression test
- existing AI pacing test continues to validate delayed production/attack behavior

### Phase 19 — Food / Farms Economy Planning
- added authoritative `food` resource
- added placeable `farm` building as a definition-driven passive food income source
- farm output is deterministic and tick-based through a dedicated structure economy system
- military production now consumes food, making economy scaling matter for attack timing
- strategic timing summary now surfaces `Build Farm` as the next goal when military tech exists but food flow does not
- normal HUD now shows food alongside wood, stone, and population
- command panel build and structure summaries now surface farm income clearly
- new focused farm/food regression coverage

### Phase 20 — Food Readiness / Scaling Depth
- added authoritative food-readiness analysis from current farm income versus military production demand
- strategic timing now distinguishes:
  - no farm yet
  - one farm but thin military sustain
  - food-ready military scaling
- pressure-stage planning can now surface `Add Farm` when current food flow is too thin for clean military timing
- normal HUD now shows food flow versus military demand, plus readiness state
- production feedback now shows food ETA when food is the missing bottleneck
- producer command summaries now surface food readiness for military buildings
- new focused food-readiness regression coverage:
  - farm income ETA to first military queue
  - one-farm vs two-farm sustain threshold
  - strategic `Add Farm` timing goal

### Phase 30 — Readability + Local Recovery Polish

- **`attack_moving` added to `TRAFFIC_PRIORITY_BY_TASK`** at priority 3 (same as `to_target`): attack-moving soldiers no longer fall through to priority 10 (lowest) and no longer yield to idle workers blocking their path
- **Player vs enemy color differentiation** — clear blue/orange-red contrast replacing the ambiguous red/dark-red scheme:
  - Player soldiers: `#e63946` (red) → `#4a7fc1` (blue) — unambiguously "player"
  - Enemy units: `#8b0000` (dark red) → `#e84a1e` (orange-red) — pops visually against player blue
  - Enemy unit icon mark: `#ff6666` → `#ffaa88` (warmer, distinct from player)
  - Enemy structures: `#6b1a1a` (near-black, hard to read) → `#c93a1a` (readable orange-red)
  - Enemy structure inner fill: `#cc4444` → `#ff7755`, border: `#3b0000` → `#7a1a00`
- No simulation state changes; no new tests needed (pure rendering + read-only priority table)

### Phase 29 — Deterministic Local Access / Egress Robustness for Workers

- **`get_interaction_slot_for_worker` rewritten** with greedy nearest-first deconfliction:
  - workers processed in sorted entity-id order; each claims the unclaimed slot nearest to their current position
  - replaces prior index-rotation (position-blind) with greedy position-aware assignment
  - deterministic: id order + Manhattan distance + (y,x) coordinate tie-break
  - O(workers × slots) = O(N × 4) — trivially bounded
  - workers approaching from different sides no longer cross paths to reach assigned slots
- new helpers on `GameState`:
  - `_raw_entity_grid_position(entity_id)` — reads `grid_position` from raw entity dict without normalize overhead
  - `_nearest_unclaimed_slot(slots, claimed, pos)` — nearest unclaimed slot from a position
  - `_slot_before(a, b)` — deterministic coordinate tie-break
- **`_assign_path_to_slot` fallback ordering** changed from lexicographic `Vector2i.sort()` to nearest-first from worker's current cell — when primary slot path fails, the closest alternative is tried first
- new `tests/interaction_slot_test.gd` with 5 tests:
  - single worker approaching from right gets right-side slot
  - worker approaching from left gets left-side slot (not right)
  - two workers at same position get different slots (spread preserved)
  - nearest-first fallback deposits correctly when primary slot is terrain-blocked
  - workers approaching from opposite sides each get their nearest slot without crossing

### Phase 28 — Attack-Move / Basic Army Command Feel

- new `commands/attack_move_command.gd` (`command_type = "attack_move"`, fields: `unit_id`, `target_cell`)
- `attack_move_target_cell: Vector2i` added to `_normalize_unit_entity` schema (default `(-1,-1)`); required for field survival through `get_entity_dict`'s normalize pass
- `CombatSystem` extended:
  - handles `"attack_move"` command: sets task `"attack_moving"`, stores destination, computes initial path
  - new `_update_attack_moving()` handler (tick loop): scans for nearest in-range enemy each tick — if found, acquire and switch to `"to_target"`/`"attacking"` (preserving `attack_move_target_cell`); if path runs out and destination not reached, repathed; if arrived, truly idle
  - new `_find_nearest_enemy_in_attack_range()`: O(entities), sorted entity_id iteration — deterministic, bounded
  - `_set_attacker_idle()` now checks `attack_move_target_cell`: if set, resumes `"attack_moving"` after combat; clears only on true arrival or path failure
- `MoveCommandSystem`: plain move command now also clears `attack_move_target_cell`
- `input_handler.gd`: ground right-click with combat units selected issues `AttackMoveCommand` instead of `MoveUnitCommand`; workers in mixed selection still get `MoveUnitCommand`; feedback message distinguishes attack-move vs pure move
- new `tests/attack_move_test.gd` with 5 tests:
  - command sets `attack_moving` state + correct destination
  - unit in `attack_moving` acquires enemy within attack range on next tick
  - unit resumes `attack_moving` after killing enemy
  - unit with no enemies arrives at destination and becomes idle
  - `MoveUnitCommand` cancels `attack_move_target_cell`

### Phase 27 — Worker Deposit / Interaction Robustness

- **Primary bug fixed**: `_update_to_stockpile` and `_update_to_resource` called `_reassign_*slot` but never wrote `worker_entity` back to `game_state.entities[entity_id]`. Because `get_entity_dict` returns a normalized copy (not a reference), all reassign results were silently discarded every tick — worker stalled indefinitely when path ran out before reaching the assigned slot. `_update_to_construction` already had the write-back; it was missing only for stockpile and resource.
- **Adjacent-position fast path**: if worker is already adjacent to the target (stockpile / resource / construction site) when a reassign is triggered, current cell is immediately adopted as the interaction slot — no repath needed. Eliminates the "wrong-slot reroute when already next to it" failure.
- **Slot fallback on blocked path**: `_assign_path_to_slot` now accepts `fallback_slots: Array[Vector2i]`. When the primary slot's BFS returns empty, tries other adjacent walkable cells in deterministic sorted order before setting worker idle. Bounded cost: at most 3 extra BFS calls (max 4 adjacent cells minus primary).
- `_reassign_stockpile_slot`, `_reassign_resource_slot`, `_reassign_construction_slot` all pass `get_adjacent_walkable_cells(target_cell)` as fallbacks and check adjacency first.
- All changes are generic over interaction target type — works for future buildings/resources without modification.
- new `tests/worker_deposit_robustness_test.gd` with 4 tests:
  - write-back fix: stalled to_stockpile worker with empty path eventually deposits
  - adjacent acceptance: worker already next to stockpile deposits within a few ticks
  - slot fallback: three of four adjacent cells terrain-blocked, worker finds the open one
  - write-back fix (resource side): stalled to_resource worker with empty path reaches gathering

### Phase 26 — Last-Seen Enemy Structure Memory

- `_seen_enemy_structures: Dictionary` (entity_id → true) added to renderer — client-side only, no simulation pollution
- when an enemy structure enters `_player_visible_cells`: marked seen, rendered normally
- when a seen enemy structure is NOT currently visible: rendered as dimmed ghost (muted dark-red, ~40% opacity, no HP bar, no construction bar — player has no real-time intel)
- when a structure has never been seen: stays fully hidden (existing behavior)
- destroyed enemy structures disappear from ghost view naturally — not in `game_state.entities` so not iterated
- `_draw_ghost_structure(cell)` helper handles all ghost drawing in one place
- no authoritative state changes; no new simulation state; bounded by entity count already scanned per frame
- no dedicated headless test (pure client-side visual state); verified via parse check + full regression suite

### Phase 25 — Minimal Visibility-Gated Presentation

- enemy units not in player visible cells are skipped in `_draw_units()` — renderer never draws them
- enemy structures not in player visible cells are skipped in `_draw_structure()` — renderer never draws them
- player's own units and structures are always drawn (owner check passes gate)
- `_player_visible_cells` computed once per `_draw()` frame via `VisibilityClass.compute_visible_cells(game_state, 1)` — no per-entity per-frame overhead
- gate is pure read-side: no GameState mutation, no new simulation state
- new `tests/visibility_gating_test.gd` with 6 tests:
  - enemy hidden when no scout nearby (player base only)
  - enemy revealed after archer moves within vision range
  - enemy base hidden (no nearby scout)
  - enemy base revealed when soldier at edge of vision radius
  - player's own base always in visible cells
  - two non-overlapping scouts see more cells than one (union)

### Phase 24 — Vision / Information Groundwork

- added `vision_radius_cells` to all unit and building definitions (definition-driven, future-extensible)
  - worker 3, soldier 4, archer 5 (ranged = best scout)
  - house/farm 2, barracks/archery_range 3, stockpile/enemy_base 4
- `vision_radius_cells` propagated through `_normalize_unit_entity` and `_normalize_structure_entity` — reads from entity or falls back to definition, same pattern as all other stats
- new `simulation/visibility.gd` (class_name Visibility) — pure read-side, no GameState mutation:
  - `compute_visible_cells(game_state, owner_id) → Dictionary` — all cells visible by owner's entities; O(entities × radius²), called on demand not per-tick
  - `is_entity_visible_to(game_state, entity_id, observer_id) → bool` — single entity lookup
  - `count_visible_enemy_units(game_state, observer_id) → int` — enemy unit intel count
  - `count_visible_cells(game_state, observer_id) → int` — coverage metric
  - Manhattan distance model, map-boundary clamped, no negative cells
- added `get_unit_vision_radius(unit_type)` and `get_building_vision_radius(building_type)` accessors to `game_definitions.gd`
- added `get_entity_vision_radius(entity)` to `game_state.gd`
- command panel: selected combat unit detail now shows `vision N` alongside attack stats
- command panel: empty-selection strategic overview shows `Intel: N enemy units in sight` when visible enemies > 0
- new `tests/visibility_test.gd` with 8 tests: definition radius values, single-unit visible cell set, out-of-range detection, enemy visibility at range, count aggregation across multiple enemies, map boundary clamping, structure vision
- **future extension points** documented in visibility.gd: last-seen state, line-of-sight blocking, shroud rendering

### Phase 23 — Production / Readiness Depth

- **army pipeline readiness** added to strategic timing: `_get_army_pipeline()` returns deployed/ready/assembling counts per owner
  - `deployed` = in active combat (to_target / attacking)
  - `ready` = idle — assembled and waiting for orders
  - `assembling` = moving to rally point, not yet at position
- `army_pipeline` dict included in `build_player_summary()` return
- empty-selection command panel now shows `Army: 2 ready, 1 assembling, 1 training` when any combat units exist
- **production batch ETA** added: `get_producer_batch_eta(game_state, producer)` computes ticks until all queued units finish training
  - formula: `(duration − progress) + (queue_count − 1) × duration`
  - shown in producer detail panel when queue > 1: `"(batch done ~40t)"`
- **fixed hardcoded "soldier" bottleneck bug**: `_get_army_bottleneck()` now uses `_get_available_combat_unit_type()` to find the right unit type generically — works correctly for archery_range producing archers, not just barracks producing soldiers
- `_get_available_combat_unit_type()` static helper: finds first combat unit type from any constructed player military producer
- new `tests/production_readiness_test.gd` with 7 tests: all-ready, all-assembling, deployed (attacking + to_target), mixed pipeline (workers excluded), single-unit batch ETA, multi-unit batch ETA, generic bottleneck fix verified for archery_range
- no new simulation state — all additions are read-side analysis (no per-tick performance impact)

### Phase 22 — Food Scaling Throughput / Performance Sanity

#### Performance fix — Static Blocker Cache
- **Root cause**: `has_static_blocker_at_cell()` iterated all entities (with `normalize_entity()` per entity) for every cell the BFS pathfinder visited. With N attacking units repathing in parallel: O(N × BFS_cells × entities × normalize_entity) per tick — the primary cause of wave-combat lag.
- **Fix**: added `static_blocker_cells: Dictionary` to `GameState` — O(1) lookup per cell
- `rebuild_static_blocker_cache()` called once at game init; reads entity dicts directly (no normalize_entity)
- `mark_static_blocker(cell)` called by `build_command_system` when a structure is definitively placed
- `has_static_blocker_at_cell()` now a single dict lookup — BFS pathfinding no longer scales with entity count

#### Food scaling depth
- added `per_producer_demand` (food demand per single military producer per analysis window)
- added `military_producer_count` (number of food-consuming military producers)
- added `can_sustain_another_producer` bool: true when income ≥ demand + per_producer_demand (surplus for full extra producer)
- added `farm_income_per_window` to food summary for UI reference
- strategic timing "ready" stage now detects food surplus and guides "Add Barracks — Food Surplus Ready" when only 1 military building exists
- command panel food line shows "→ add Barracks" hint when `can_sustain_another_producer`
- new `tests/food_scaling_test.gd` with 5 tests: static blocker cache, no-surplus with 0 farms, no-surplus with 1 farm + 1 barracks (income 30 < demand 32 + 32), surplus with 3 farms + 1 barracks (income 90 ≥ demand 64), per_producer_demand value

### Phase 21 — Combat Counters / Tactical Readability
- definition-driven role-to-role damage multiplier table in `game_definitions.gd`
- archer counters soldiers (+50%), workers (+25%); soldier counters workers (+50%), archers (+25%)
- integer-only multiplier arithmetic `(base_damage * multiplier) / 100` — determinism preserved
- CombatSystem applies multiplier via `get_damage_multiplier(attacker_role, target_role)`
- `get_counter_label(role) → String` for UI display (e.g. "+50% vs soldiers, +25% vs workers")
- selected combat units show "Strong vs" counter label in command panel detail
- train button tooltips show counter strengths for units being queued
- new `tests/combat_counter_test.gd` with 5 tests: multiplier table API, label strings, archer bonus kill, soldier bonus kill, neutral matchup survival

## Current Regression Coverage

- `tests/gather_test.gd`
- `tests/construction_test.gd`
- `tests/combat_test.gd`
- `tests/stone_prerequisite_test.gd`
- `tests/ai_winlose_test.gd`
- `tests/population_supply_test.gd`
- `tests/entity_schema_test.gd`
- `tests/strategic_timing_test.gd`
- `tests/rally_test.gd`
- `tests/congestion_recovery_test.gd`
- `tests/farm_food_test.gd`
- `tests/food_readiness_test.gd`
- `tests/visibility_test.gd`
- `tests/production_readiness_test.gd`
- `tests/food_scaling_test.gd`
- `tests/combat_counter_test.gd`
- `tests/visibility_gating_test.gd`
- `tests/worker_deposit_robustness_test.gd`
- `tests/attack_move_test.gd`
- `tests/interaction_slot_test.gd`
- `tests/ai_winlose_test.gd` now also covers generic combat producer AI usage
- `tests/combat_test.gd` now also covers ranged attack behavior
- `tests/strategic_timing_test.gd` now also covers the farm-stage timing summary

## Best Next Work

### Option A — Food Scaling Throughput
- deepen what happens after the first `Add Farm` decision
- make multi-producer food saturation and military scaling more legible
- keep passive-income buildings and future economy structures definition-driven

### Option B — Production / Readiness Depth
- add richer producer-state clarity such as queue staging, readiness, or deployment planning
- preserve generic producer behavior so future buildings can plug in cleanly
- improve timing conversion from economy into fielded army

### Option C — Vision / Information Layer
- vision radius groundwork
- fog-of-war-friendly authoritative visibility data
- support for future scouting and information asymmetry

### Option D — Multiplayer Foundation
- only after gameplay/system shape stabilizes
- lockstep validation
- serialization/desync hardening
- replay verification expansion

## Recommended Order

1. deepen food scaling and throughput planning on top of the new readiness layer
2. then deepen tactical readability or simple counters if needed
3. only then add visibility/fog-of-war-friendly data if desired
4. after gameplay confidence is high, start multiplayer/lockstep work

## Not Started Yet

- multiplayer / lockstep synchronization
- replay playback UI
- save/load
- upgrades / tech tree
- fog of war
- advanced building footprints
- broad AI strategy layer
- broad formation / squad behavior

## Rules

- keep changes incremental and runnable
- preserve deterministic authoritative boundaries
- input and AI must issue commands only
- systems are the only place that mutate `GameState`
- content values and default stats belong in `simulation/game_definitions.gd`
- prefer coherent vertical slices over broad placeholder architecture
