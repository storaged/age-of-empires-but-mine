extends SceneTree

## Headless tests: per-unit vision radius definitions and authoritative visibility queries.

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const VisibilityClass = preload("res://simulation/visibility.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const OWNER_ID: int = 1
const ENEMY_ID: int = 2


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_vision_radius_definitions_test())
	failures.append_array(run_single_unit_visible_cells_test())
	failures.append_array(run_out_of_range_not_visible_test())
	failures.append_array(run_enemy_unit_visible_test())
	failures.append_array(run_enemy_unit_out_of_range_test())
	failures.append_array(run_count_visible_enemy_units_test())
	failures.append_array(run_map_boundary_clamp_test())
	failures.append_array(run_structure_vision_test())
	if failures.is_empty():
		print("VISIBILITY_TEST: PASS")
	else:
		print("VISIBILITY_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: vision radii in definitions match expected values.
func run_vision_radius_definitions_test() -> Array[String]:
	var failures: Array[String] = []
	var cases: Array[Array] = [
		["worker",   3],
		["soldier",  4],
		["archer",   5],
	]
	for c in cases:
		var unit_type: String = str(c[0])
		var expected: int = int(c[1])
		var got: int = GameDefinitionsClass.get_unit_vision_radius(unit_type)
		if got != expected:
			failures.append("[defs] %s vision_radius: expected %d, got %d" % [unit_type, expected, got])

	var building_cases: Array[Array] = [
		["house",          2],
		["farm",           2],
		["barracks",       3],
		["archery_range",  3],
	]
	for c in building_cases:
		var btype: String = str(c[0])
		var expected: int = int(c[1])
		var got: int = GameDefinitionsClass.get_building_vision_radius(btype)
		if got != expected:
			failures.append("[defs] building %s vision_radius: expected %d, got %d" % [btype, expected, got])

	print("[defs] unit vision radii: worker=%d soldier=%d archer=%d" % [
		GameDefinitionsClass.get_unit_vision_radius("worker"),
		GameDefinitionsClass.get_unit_vision_radius("soldier"),
		GameDefinitionsClass.get_unit_vision_radius("archer"),
	])
	return failures


## Test 2: soldier at (5,5) with radius 4 → center cell visible, radius-4 cell visible.
func run_single_unit_visible_cells_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", unit_id, OWNER_ID, Vector2i(5, 5), 0
	)

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, OWNER_ID)

	# Center cell must be visible
	if not visible.has("5,5"):
		failures.append("[single] center cell (5,5) not visible")
	# Manhattan distance 4 from (5,5) → (5,9) should be visible
	if not visible.has("5,9"):
		failures.append("[single] cell (5,9) at Manhattan dist 4 not visible (radius=4)")
	# (5,10) is distance 5 — beyond radius 4, should NOT be visible
	if visible.has("5,10"):
		failures.append("[single] cell (5,10) at dist 5 should not be visible (radius=4)")

	var cell_count: int = visible.size()
	print("[single] soldier at (5,5) radius=4 → %d visible cells" % cell_count)
	return failures


## Test 3: cell 5 away from soldier (radius 4) is not visible.
func run_out_of_range_not_visible_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", unit_id, OWNER_ID, Vector2i(5, 5), 0
	)

	# Place an "enemy" unit at distance 5 from soldier
	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(5, 10), 0
	)

	var is_visible: bool = VisibilityClass.is_entity_visible_to(game_state, enemy_id, OWNER_ID)
	if is_visible:
		failures.append("[out_of_range] enemy at dist 5 should not be visible by soldier (radius 4)")
	print("[out_of_range] enemy at (5,10) visible to soldier at (5,5): %s" % is_visible)
	return failures


## Test 4: enemy unit at Manhattan dist ≤ 4 from soldier IS visible.
func run_enemy_unit_visible_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", unit_id, OWNER_ID, Vector2i(5, 5), 0
	)
	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(8, 5), 0  # dist 3
	)

	var is_visible: bool = VisibilityClass.is_entity_visible_to(game_state, enemy_id, OWNER_ID)
	if not is_visible:
		failures.append("[visible] enemy at dist 3 should be visible by soldier (radius 4)")
	print("[visible] enemy at (8,5) visible to soldier at (5,5): %s" % is_visible)
	return failures


## Test 5: enemy unit beyond all player vision radii is NOT visible.
func run_enemy_unit_out_of_range_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = GameDefinitionsClass.create_unit_entity(
		"worker", unit_id, OWNER_ID, Vector2i(1, 1), 0  # radius 3
	)
	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(10, 10), 0  # dist 18 from worker
	)

	var is_visible: bool = VisibilityClass.is_entity_visible_to(game_state, enemy_id, OWNER_ID)
	if is_visible:
		failures.append("[out_of_range2] enemy at (10,10) should not be visible from worker at (1,1) radius 3")
	print("[out_of_range2] enemy at (10,10) visible from worker at (1,1): %s" % is_visible)
	return failures


## Test 6: count_visible_enemy_units aggregates across multiple units.
func run_count_visible_enemy_units_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Player archer at (5,5) with radius 5
	var archer_id: int = game_state.allocate_entity_id()
	game_state.entities[archer_id] = GameDefinitionsClass.create_unit_entity(
		"archer", archer_id, OWNER_ID, Vector2i(5, 5), 0
	)

	# 2 enemies in range (dist ≤ 5), 1 out of range
	var e1_id: int = game_state.allocate_entity_id()
	game_state.entities[e1_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", e1_id, ENEMY_ID, Vector2i(7, 5), 0  # dist 2
	)
	var e2_id: int = game_state.allocate_entity_id()
	game_state.entities[e2_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", e2_id, ENEMY_ID, Vector2i(5, 9), 0  # dist 4
	)
	var e3_id: int = game_state.allocate_entity_id()
	game_state.entities[e3_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", e3_id, ENEMY_ID, Vector2i(5, 12), 0  # dist 7
	)

	var visible_count: int = VisibilityClass.count_visible_enemy_units(game_state, OWNER_ID)
	if visible_count != 2:
		failures.append("[count] Expected 2 visible enemy units, got %d" % visible_count)
	print("[count] visible_enemy_units with archer at (5,5): %d" % visible_count)
	return failures


## Test 7: visibility is clamped at map boundaries (no negative or out-of-bounds cells).
func run_map_boundary_clamp_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Soldier at corner (0,0) with radius 4 — would go negative without clamping
	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", unit_id, OWNER_ID, Vector2i(0, 0), 0
	)

	var visible: Dictionary = VisibilityClass.compute_visible_cells(game_state, OWNER_ID)

	# (0,0) must be visible
	if not visible.has("0,0"):
		failures.append("[boundary] (0,0) should be visible")
	# No negative key should exist
	for key in visible.keys():
		var parts: Array = str(key).split(",")
		if parts.size() == 2:
			var x: int = int(parts[0])
			var y: int = int(parts[1])
			if x < 0 or y < 0:
				failures.append("[boundary] negative cell in visible set: %s" % key)
				break
			if x >= MAP_WIDTH or y >= MAP_HEIGHT:
				failures.append("[boundary] out-of-bounds cell in visible set: %s" % key)
				break

	print("[boundary] soldier at (0,0) radius=4 → %d visible cells (no negatives)" % visible.size())
	return failures


## Test 8: constructed structure provides vision via vision_radius_cells from defs.
func run_structure_vision_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Place a constructed barracks (vision_radius=3) at (10,5) for owner 1
	var barracks_id: int = game_state.allocate_entity_id()
	game_state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks", barracks_id, OWNER_ID, Vector2i(10, 5), true
	)

	# Enemy unit at dist 3 from barracks
	var enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", enemy_id, ENEMY_ID, Vector2i(10, 8), 0  # dist 3
	)

	var is_visible: bool = VisibilityClass.is_entity_visible_to(game_state, enemy_id, OWNER_ID)
	if not is_visible:
		failures.append("[structure] enemy at dist 3 should be visible by barracks (radius=3)")

	# Enemy at dist 4 — beyond barracks vision
	var far_enemy_id: int = game_state.allocate_entity_id()
	game_state.entities[far_enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", far_enemy_id, ENEMY_ID, Vector2i(10, 9), 0  # dist 4
	)
	var far_visible: bool = VisibilityClass.is_entity_visible_to(game_state, far_enemy_id, OWNER_ID)
	if far_visible:
		failures.append("[structure] enemy at dist 4 should NOT be visible by barracks alone (radius=3)")

	print("[structure] barracks vision: enemy at dist 3=%s, dist 4=%s" % [is_visible, far_visible])
	return failures


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
