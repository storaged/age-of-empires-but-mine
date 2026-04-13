extends SceneTree

## Headless tests: visibility-gated presentation logic.
## Validates the visibility queries that gate enemy rendering in renderer.gd.
## (Renderer itself requires a scene tree; these tests cover the authoritative logic.)

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const VisibilityClass = preload("res://simulation/visibility.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const PLAYER_ID: int = 1
const ENEMY_ID: int = 2


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_enemy_hidden_without_scout_test())
	failures.append_array(run_enemy_revealed_by_scout_test())
	failures.append_array(run_enemy_base_hidden_test())
	failures.append_array(run_enemy_base_revealed_test())
	failures.append_array(run_player_base_always_visible_test())
	failures.append_array(run_multiple_scouts_union_test())
	if failures.is_empty():
		print("VISIBILITY_GATING_TEST: PASS")
	else:
		print("VISIBILITY_GATING_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: enemy unit far from all player units is NOT in player visible cells.
## This is the condition renderer uses to skip drawing enemy entities.
func run_enemy_hidden_without_scout_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_player_base()

	# Player base at (2,2), stockpile vision=4. Enemy unit at (17,8) — far away.
	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(17, 8), 0
	)

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)
	var enemy_cell_key: String = game_state.cell_key(Vector2i(17, 8))
	if visible.has(enemy_cell_key):
		failures.append("[hidden] Enemy at (17,8) should not be in player visible cells — too far from base")

	print("[hidden] enemy at (17,8) visible from player base at (2,2): %s" % visible.has(enemy_cell_key))
	return failures


## Test 2: after scouting archer moves near enemy, enemy enters visible cells.
func run_enemy_revealed_by_scout_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_player_base()

	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(17, 8), 0
	)

	# Before scout: enemy hidden
	var visible_before: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)
	var enemy_key: String = game_state.cell_key(Vector2i(17, 8))
	if visible_before.has(enemy_key):
		failures.append("[scout_reveal] Enemy should be hidden before scout moves close")

	# Add player archer at (14, 8) — radius 5, dist to enemy = 3 → reveals it
	var scout_id: int = game_state.allocate_entity_id()
	game_state.entities[scout_id] = GameDefinitionsClass.create_unit_entity(
		"archer", scout_id, PLAYER_ID, Vector2i(14, 8), 0
	)
	game_state.occupancy[game_state.cell_key(Vector2i(14, 8))] = scout_id

	var visible_after: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)
	if not visible_after.has(enemy_key):
		failures.append("[scout_reveal] Enemy at (17,8) should be visible after archer moves to (14,8) (dist=3, radius=5)")

	print("[scout_reveal] enemy visible before scout: %s, after: %s" % [
		visible_before.has(enemy_key), visible_after.has(enemy_key)
	])
	return failures


## Test 3: enemy base structure hidden when no player unit is nearby.
func run_enemy_base_hidden_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_player_base()

	var enemy_base_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_base_id] = GameDefinitionsClass.create_structure_entity(
		"enemy_base", enemy_base_id, ENEMY_ID, Vector2i(17, 8), true
	)

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)
	var base_key: String = game_state.cell_key(Vector2i(17, 8))
	if visible.has(base_key):
		failures.append("[base_hidden] Enemy base at (17,8) should not be visible from player base only")

	print("[base_hidden] enemy base visible (no scout): %s" % visible.has(base_key))
	return failures


## Test 4: enemy base visible once player soldier is close enough.
func run_enemy_base_revealed_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_player_base()

	var enemy_base_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_base_id] = GameDefinitionsClass.create_structure_entity(
		"enemy_base", enemy_base_id, ENEMY_ID, Vector2i(17, 8), true
	)

	# Player soldier at (13, 8) with radius 4 → dist to (17,8) = 4 → just on edge
	var soldier_id: int = game_state.allocate_entity_id()
	game_state.entities[soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", soldier_id, PLAYER_ID, Vector2i(13, 8), 0
	)
	game_state.occupancy[game_state.cell_key(Vector2i(13, 8))] = soldier_id

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)
	var base_key: String = game_state.cell_key(Vector2i(17, 8))
	if not visible.has(base_key):
		failures.append("[base_revealed] Enemy base at (17,8) should be visible by soldier at (13,8) (dist=4, radius=4)")

	print("[base_revealed] enemy base visible by soldier at (13,8): %s" % visible.has(base_key))
	return failures


## Test 5: player's own structures are always visible (owner check passes).
func run_player_base_always_visible_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_player_base()

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, PLAYER_ID)

	# Player base cell (2,2) — stockpile sees itself (radius=4, dist=0)
	var stockpile_key: String = game_state.cell_key(Vector2i(2, 2))
	if not visible.has(stockpile_key):
		failures.append("[always_visible] Player base cell (2,2) should always be in visible cells")

	print("[always_visible] player base cell (2,2) in visible cells: %s" % visible.has(stockpile_key))
	return failures


## Test 6: two scouts with non-overlapping vision cover more area than one.
## Visible cell count with 2 scouts > visible cell count with 1 scout.
func run_multiple_scouts_union_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Single soldier at (3,3) — radius 4
	var s1_id: int = game_state.allocate_entity_id()
	game_state.entities[s1_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", s1_id, PLAYER_ID, Vector2i(3, 3), 0
	)

	var count_one: int = VisibilityClass.count_visible_cells(game_state, PLAYER_ID)

	# Add second soldier far away at (16, 10) — radius 4, non-overlapping
	var s2_id: int = game_state.allocate_entity_id()
	game_state.entities[s2_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", s2_id, PLAYER_ID, Vector2i(16, 10), 0
	)

	var count_two: int = VisibilityClass.count_visible_cells(game_state, PLAYER_ID)
	if count_two <= count_one:
		failures.append("[union] Two non-overlapping scouts should see more cells than one (got %d vs %d)" % [count_two, count_one])

	print("[union] visible cells: 1 scout=%d, 2 scouts=%d" % [count_one, count_two])
	return failures


## ── helpers ──────────────────────────────────────────────────────────────────


func _make_bare_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0, "food": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": 64,
		"blocked_cells": {},
	}
	return state


## State with a player stockpile at (2,2) — vision radius 4.
func _make_game_state_with_player_base() -> GameState:
	var state: GameState = _make_bare_game_state()
	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_stockpile_entity(
		stockpile_id, PLAYER_ID, Vector2i(2, 2)
	)
	return state
