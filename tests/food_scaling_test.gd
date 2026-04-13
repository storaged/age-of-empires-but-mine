extends SceneTree

## Headless tests: food scaling throughput and static blocker cache.

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const FoodReadinessClass = preload("res://simulation/food_readiness.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64
const OWNER_ID: int = 1


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_static_blocker_cache_test())
	failures.append_array(run_no_farms_no_sustain_test())
	failures.append_array(run_one_farm_one_barracks_not_surplus_test())
	failures.append_array(run_surplus_enables_scale_signal_test())
	failures.append_array(run_per_producer_demand_test())
	if failures.is_empty():
		print("FOOD_SCALING_TEST: PASS")
	else:
		print("FOOD_SCALING_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: static blocker cache populated by rebuild and mark.
func run_static_blocker_cache_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Initially empty
	if game_state.has_static_blocker_at_cell(Vector2i(3, 3)):
		failures.append("[blocker] Cell (3,3) should not be blocked before any entity placed")

	# Place a resource node at (3,3) directly, then rebuild cache
	var node_id: int = game_state.allocate_entity_id()
	game_state.entities[node_id] = GameDefinitionsClass.create_resource_node_entity(
		"wood", node_id, Vector2i(3, 3), 80
	)
	game_state.rebuild_static_blocker_cache()

	if not game_state.has_static_blocker_at_cell(Vector2i(3, 3)):
		failures.append("[blocker] Cell (3,3) should be blocked after resource node placed + cache rebuilt")
	if game_state.has_static_blocker_at_cell(Vector2i(4, 4)):
		failures.append("[blocker] Cell (4,4) should not be blocked — no entity there")

	# mark_static_blocker directly
	game_state.mark_static_blocker(Vector2i(7, 7))
	if not game_state.has_static_blocker_at_cell(Vector2i(7, 7)):
		failures.append("[blocker] Cell (7,7) should be blocked after mark_static_blocker")
	if game_state.has_static_blocker_at_cell(Vector2i(8, 8)):
		failures.append("[blocker] Cell (8,8) should not be blocked")

	print("[blocker] static_blocker_cells has %d entries" % game_state.static_blocker_cells.size())
	return failures


## Test 2: no farms → no sustain, can_sustain_another_producer = false.
func run_no_farms_no_sustain_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_barracks(0, 1)
	var summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, OWNER_ID)

	var can_sustain: bool = bool(summary.get("can_sustain_another_producer", false))
	if can_sustain:
		failures.append("[sustain] 0 farms + 1 barracks should not signal can_sustain_another_producer")
	var status: String = str(summary.get("status_id", ""))
	if status not in ["starved", "unstarted"]:
		failures.append("[sustain] 0 farms + 1 barracks should be starved or unstarted, got: %s" % status)
	print("[sustain] 0 farms: status=%s, can_sustain=%s" % [status, can_sustain])
	return failures


## Test 3: 1 farm + 1 barracks → food is thin/ready but income barely covers demand.
## Soldier: 4 food, 15 ticks → demand per 120t = ceil(120×4/15) = 32.
## Farm: 2 food / 8 ticks → income per 120t = floor(120×2/8) = 30.
## Income(30) < demand(32) → thin, cannot sustain another.
func run_one_farm_one_barracks_not_surplus_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_barracks(1, 1)
	var summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, OWNER_ID)

	var income: int = int(summary.get("income_per_window", 0))
	var demand: int = int(summary.get("demand_per_window", 0))
	var can_sustain: bool = bool(summary.get("can_sustain_another_producer", false))

	# 1 farm income should be 30
	if income != 30:
		failures.append("[1farm] Expected income=30, got %d" % income)
	# 1 barracks (soldier) demand should be 32
	if demand != 32:
		failures.append("[1farm] Expected demand=32 (soldier 4 food / 15 ticks / 120t window), got %d" % demand)
	if can_sustain:
		failures.append("[1farm] 1 farm + 1 barracks should not signal can_sustain_another_producer (income 30 < demand 32 + 32)")
	print("[1farm] income=%d, demand=%d, can_sustain=%s" % [income, demand, can_sustain])
	return failures


## Test 4: 3 farms + 1 barracks → income surplus → can_sustain_another_producer = true.
## 3 farms: income = 90 per 120t.
## 1 barracks demand = 32. Surplus = 58 ≥ 32 → can sustain another.
func run_surplus_enables_scale_signal_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_barracks(3, 1)
	var summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, OWNER_ID)

	var income: int = int(summary.get("income_per_window", 0))
	var demand: int = int(summary.get("demand_per_window", 0))
	var can_sustain: bool = bool(summary.get("can_sustain_another_producer", false))

	# 3 farms: income = floor(120×2/8) × 3 = 30×3 = 90
	if income != 90:
		failures.append("[surplus] Expected income=90 (3 farms), got %d" % income)
	if demand != 32:
		failures.append("[surplus] Expected demand=32 (1 soldier barracks), got %d" % demand)
	if not can_sustain:
		failures.append("[surplus] 3 farms + 1 barracks: income(%d) ≥ demand(%d) + per_producer(%d) — should signal can_sustain_another" % [
			income, demand, int(summary.get("per_producer_demand", 0))
		])
	var status: String = str(summary.get("status_id", ""))
	if status != "ready":
		failures.append("[surplus] Expected status=ready with 3 farms + 1 barracks, got %s" % status)
	print("[surplus] income=%d, demand=%d, can_sustain=%s, status=%s" % [income, demand, can_sustain, status])
	return failures


## Test 5: per_producer_demand returns representative value for the barracks unit type.
func run_per_producer_demand_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state_with_barracks(1, 1)
	var summary: Dictionary = FoodReadinessClass.build_food_summary(game_state, OWNER_ID)

	var per_producer: int = int(summary.get("per_producer_demand", 0))
	# Soldier: 4 food, 15 ticks production → ceil(120×4/15) = ceil(32) = 32
	if per_producer != 32:
		failures.append("[per_producer] Expected 32 per_producer_demand for soldier barracks, got %d" % per_producer)
	var military_count: int = int(summary.get("military_producer_count", 0))
	if military_count != 1:
		failures.append("[per_producer] Expected military_producer_count=1, got %d" % military_count)
	print("[per_producer] per_producer_demand=%d, military_producer_count=%d" % [per_producer, military_count])
	return failures


func _make_bare_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0, "food": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": {},
	}
	return state


## Create a state with N farms and M soldier barracks for owner 1.
func _make_game_state_with_barracks(farm_count: int, barracks_count: int) -> GameState:
	var state: GameState = _make_bare_game_state()

	for i in range(farm_count):
		var farm_id: int = state.allocate_entity_id()
		var farm_cell: Vector2i = Vector2i(10 + i, 2)
		state.entities[farm_id] = GameDefinitionsClass.create_structure_entity(
			"farm", farm_id, OWNER_ID, farm_cell, true
		)

	for i in range(barracks_count):
		var barracks_id: int = state.allocate_entity_id()
		var barracks_cell: Vector2i = Vector2i(10 + i, 5)
		state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
			"barracks", barracks_id, OWNER_ID, barracks_cell, true
		)

	return state
