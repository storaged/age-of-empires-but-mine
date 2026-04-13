extends SceneTree

const FoodReadinessClass = preload("res://simulation/food_readiness.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const StrategicTimingClass = preload("res://simulation/strategic_timing.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_food_eta_test())
	failures.append_array(run_food_scale_threshold_test())
	failures.append_array(run_strategic_add_farm_goal_test())
	if failures.is_empty():
		print("FOOD_READINESS_TEST: PASS")
	else:
		print("FOOD_READINESS_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_food_eta_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_food_state(1, false)
	var soldier_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs("soldier")
	var required_food_value: Variant = soldier_costs.get("food", 0)
	var required_food: int = required_food_value if required_food_value is int else 0
	var eta_ticks: int = FoodReadinessClass.estimate_ticks_until_resource_amount(
		game_state,
		1,
		"food",
		required_food
	)
	if eta_ticks != 16:
		failures.append("[eta] Expected 16 ticks for one farm to reach soldier food, got %d." % eta_ticks)
	return failures


func run_food_scale_threshold_test() -> Array[String]:
	var failures: Array[String] = []
	var one_farm_state: GameState = _create_food_state(1, false)
	var one_farm_summary: Dictionary = FoodReadinessClass.build_food_summary(one_farm_state, 1)
	if str(one_farm_summary.get("status_id", "")) != "thin":
		failures.append("[scale] Expected one farm to be thin for barracks throughput.")

	var two_farm_state: GameState = _create_food_state(2, false)
	var two_farm_summary: Dictionary = FoodReadinessClass.build_food_summary(two_farm_state, 1)
	if str(two_farm_summary.get("status_id", "")) != "ready":
		failures.append("[scale] Expected two farms to be ready for barracks throughput.")

	return failures


func run_strategic_add_farm_goal_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_food_state(1, true)
	var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	if str(summary.get("next_goal", "")) != "Add Farm":
		failures.append("[timing] Expected Add Farm goal when one farm is thin for military scaling.")
	return failures


func _create_food_state(farm_count: int, include_combat_units: bool) -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"food": 0, "wood": 200, "stone": 50}
	state.map_data = {"width": 12, "height": 12, "cell_size": 64, "blocked_cells": {}}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_stockpile_entity(
		stockpile_id,
		1,
		Vector2i(2, 2)
	)

	var house_id: int = state.allocate_entity_id()
	state.entities[house_id] = GameDefinitionsClass.create_structure_entity(
		"house",
		house_id,
		1,
		Vector2i(3, 2)
	)

	var barracks_id: int = state.allocate_entity_id()
	state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks",
		barracks_id,
		1,
		Vector2i(4, 2)
	)

	for farm_index in range(farm_count):
		var farm_id: int = state.allocate_entity_id()
		state.entities[farm_id] = GameDefinitionsClass.create_structure_entity(
			"farm",
			farm_id,
			1,
			Vector2i(5 + farm_index, 2)
		)

	if include_combat_units:
		var soldier_id: int = state.allocate_entity_id()
		state.entities[soldier_id] = GameDefinitionsClass.create_unit_entity(
			"soldier",
			soldier_id,
			1,
			Vector2i(2, 3),
			0
		)

	return state
