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

### Phase 32 — Scenario Setup / Real Match Config
- moved match-start scenario layout out of hardcoded gameplay scene logic and into small deterministic preset files
- added preset layer:
  - `simulation/presets/map_presets.gd`
  - `simulation/presets/ai_presets.gd`
  - `simulation/presets/color_presets.gd`
- `MatchConfig` now transports:
  - selected preset ids
  - resolved map layout data
  - resolved AI aggression timing
  - resolved faction color values
- pregame now exposes selectors for:
  - map preset
  - AI aggression preset
  - color preset
- added at least 2 selectable map presets with distinct initial authoritative layouts
- added 3 AI aggression presets:
  - Relaxed
  - Standard
  - Rush
- renderer now consumes color preset values through `MatchConfig`
- gameplay scene now builds initial `GameState` from `MatchConfig`, not its own hardcoded scenario source
- new focused regression coverage for map preset divergence, AI timing preset application, and color/default transport

### Phase 33 — Visual Language + Juice Pass
- renderer upgraded from debug geometry toward a coherent procedural RTS prototype visual language
- terrain now has layered ground treatment instead of flat debug fill only
- obstacles now read more clearly as ridges / rocks with shadow and highlight
- units now have stronger silhouettes, role glyphs, faction accents, and softer authoritative markers
- structures now have clearer type silhouettes:
  - stockpile
  - house
  - farm
  - barracks
  - archery range
  - enemy structures

### Phase 34 — Scenario Layer + Mission HUD Reframe
- headless scenario data split into maps, enemy plans, and scenarios
- deterministic scenario runtime now evaluated from authoritative ticks
- 3 authored scenarios with distinct layout / pressure / objectives
- pregame became scenario-first instead of raw sandbox config
- HUD reframed into mission panel + alerts + cleaner player-facing hierarchy

### Phase 35 — Deterministic Movement Recovery + Safe Spawn / Reservation
- deterministic nearest-valid spawn resolution for initial and scripted unit spawns
- initial structure placement now resolves against blocked/resource/static cells deterministically
- reserved/static footprint changes now invalidate stale paths and trigger bounded recovery
- melee attackers now claim deterministic reachable attack slots instead of piling into one lane
- blocker cache now rebuilds cleanly after static entity death
- new regression coverage for spawn resolution, stale-path recovery, worker/build contention, and melee pressure

### Phase 36 — Deterministic Task Revalidation + General Deadlock Breakers
- movement recovery now escalates from stale path to stale intent
- worker logistics tasks revalidate stockpile/resource/construction targets and slots
- workers retarget or idle cleanly when delivery/resource/construction targets vanish or become invalid
- attack / attack-move states revalidate stale target slots instead of preserving old blocked intent
- plain move / rally intents now abandon unreachable stale loops deterministically
- added regression coverage for destroyed stockpile, depleted resource, invalid construction, reciprocal worker deadlock, and unreachable stale intent

### Phase 37 — Service-Cell Yielding + First Asset-Backed Presentation
- authoritative service-cell helpers now mark operational cells around:
  - stockpiles
  - resource nodes
  - construction/structure footprints
  - melee structure approach cells
- idle units standing in service cells now vacate to nearest deterministic parking cell
- active friendly traffic can trigger idle friendly blockers to yield from service cells
- added regression coverage for:
  - idle blocker vacating stockpile service access
  - idle blocker vacating local gather/build service lane
- renderer now uses local Kenney assets with safe fallback for:
  - terrain tiles
  - obstacles
  - resources
  - structures
  - units
  - projectile / hit / completion effects
- command panel and pregame now use first-pass Kenney UI skin + lightweight UI audio
- gameplay HUD panels now have first-pass asset skin and alert audio
- renderer/client stayed read-only; authoritative gameplay changes limited to deterministic movement yield rules

### Phase 38 — Camera / Scale / Tile Composition / Readability
- `rendering/asset_aliases_medieval_rts.gd` is now respected through `asset_catalog.gd` for human-approved medieval RTS alias mapping
- renderer now distinguishes semantic tile classes:
  - base terrain
  - full road tiles
  - road overlays
  - decorative tree clusters
  - farm plot tiles
- ground composition is now deterministic and region-based instead of noisy checkerboard-per-cell tiling
- roads now appear as logical service strips around structures/resources instead of random tile variation
- default gameplay camera starts closer for larger/more readable unit and structure presentation
- units/resources/structures render materially larger with safer feet/base anchoring
- unit selectors moved to softer under-sprite rings so they no longer dominate the silhouette
- added light presentation motion/readability polish:
  - subtle idle bob
  - selection pulse
  - clearer projectile sprite sizing
  - cleaner completion pulse scale
- HUD/panel sizing tightened to fit the closer world framing without swallowing screen space

## Current Regression Coverage (23 tests)

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
godot4 --headless --script tests/scenario_setup_test.gd
godot4 --headless --script tests/scenario_runtime_test.gd
```

## Best Next Work

### Option A — Mission-Specific Enemy Plans
- keep scenario layer, but make enemy plans feel more distinct than timing only
- examples: hold-position wave, flank route, delayed tech switch
- still deterministic and command-driven

### Option B — Mission-Specific Objectives / Rewards
- richer objective chains and scenario events on top of the new runtime
- examples: protect caravan, hold chokepoint, build by deadline

### Option C — Cleaner Game HUD / Selection Info
- now that mission HUD exists, refine selection/readiness panel hierarchy further
- keep player-facing HUD and debug overlay clearly separated

### Option D — Multiplayer / Lockstep Foundation
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
- generic scenario editor

## Rules

- keep changes incremental and runnable
- preserve deterministic authoritative boundaries
- input and AI must issue commands only
- systems are the only place that mutate `GameState`
- content values and default stats belong in `simulation/game_definitions.gd`
- any new unit field must be added to `_normalize_unit_entity` in `game_definitions.gd`
- prefer coherent vertical slices over broad placeholder architecture
