extends SceneTree

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const StrategicTimingClass = preload("res://simulation/strategic_timing.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_stabilize_summary_test())
	failures.append_array(run_scale_summary_test())
	failures.append_array(run_farm_timing_summary_test())
	failures.append_array(run_pressure_ready_summary_test())
	if failures.is_empty():
		print("STRATEGIC_TIMING_TEST: PASS")
	else:
		print("STRATEGIC_TIMING_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_stabilize_summary_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_base_state()

	var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	if str(summary.get("stage_id", "")) != "stabilize":
		failures.append("[stabilize] Expected stage stabilize.")
	if str(summary.get("next_goal", "")) != "Build House":
		failures.append("[stabilize] Expected next goal Build House.")
	if not str(summary.get("bottleneck", "")).contains("Need"):
		failures.append("[stabilize] Expected a resource bottleneck for house timing.")

	return failures


func run_scale_summary_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_base_state()
	var house_id: int = game_state.allocate_entity_id()
	game_state.entities[house_id] = GameDefinitionsClass.create_structure_entity(
		"house",
		house_id,
		1,
		Vector2i(4, 4)
	)
	game_state.current_tick = 150

	var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	if str(summary.get("stage_id", "")) != "scale":
		failures.append("[scale] Expected stage scale.")
	if str(summary.get("next_goal", "")) != "Build Barracks":
		failures.append("[scale] Expected next goal Build Barracks.")

	return failures


func run_pressure_ready_summary_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_base_state()
	var house_id: int = game_state.allocate_entity_id()
	var barracks_id: int = game_state.allocate_entity_id()
	game_state.entities[house_id] = GameDefinitionsClass.create_structure_entity(
		"house",
		house_id,
		1,
		Vector2i(4, 4)
	)
	game_state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks",
		barracks_id,
		1,
		Vector2i(5, 4)
	)
	var soldier_a_id: int = game_state.allocate_entity_id()
	var soldier_b_id: int = game_state.allocate_entity_id()
	game_state.entities[soldier_a_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		soldier_a_id,
		1,
		Vector2i(2, 2),
		0
	)
	game_state.entities[soldier_b_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		soldier_b_id,
		1,
		Vector2i(3, 2),
		0
	)

	var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	if str(summary.get("stage_id", "")) != "ready":
		failures.append("[ready] Expected stage ready with two combat units.")
	if str(summary.get("next_goal", "")) != "Attack Before The Next Wave":
		failures.append("[ready] Expected timing goal to attack before next wave.")
	var pressure_text: String = StrategicTimingClass.get_enemy_pressure_text(game_state)
	if pressure_text == "":
		failures.append("[ready] Expected non-empty enemy pressure text.")

	return failures


func run_farm_timing_summary_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_base_state()
	var house_id: int = game_state.allocate_entity_id()
	var barracks_id: int = game_state.allocate_entity_id()
	game_state.entities[house_id] = GameDefinitionsClass.create_structure_entity(
		"house",
		house_id,
		1,
		Vector2i(4, 4)
	)
	game_state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks",
		barracks_id,
		1,
		Vector2i(5, 4)
	)

	var summary: Dictionary = StrategicTimingClass.build_player_summary(game_state, 1)
	if str(summary.get("next_goal", "")) != "Build Farm":
		failures.append("[farm_stage] Expected next goal Build Farm after barracks with no farm.")
	if not str(summary.get("bottleneck", "")).contains("Need"):
		failures.append("[farm_stage] Expected a concrete farm-stage bottleneck.")
	return failures


func _create_base_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"food": 0, "wood": 10, "stone": 0}
	state.map_data = {"width": 12, "height": 12, "cell_size": 64, "blocked_cells": {}}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_stockpile_entity(
		stockpile_id,
		1,
		Vector2i(2, 2)
	)

	for worker_cell in [Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(4, 2)]:
		var worker_id: int = state.allocate_entity_id()
		state.entities[worker_id] = GameDefinitionsClass.create_unit_entity(
			"worker",
			worker_id,
			1,
			worker_cell,
			stockpile_id
		)

	return state
