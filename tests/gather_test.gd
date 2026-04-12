extends SceneTree

## Headless test: verifies that a gather command causes workers to enter to_resource state and move.

const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const GatherResourceCommandClass = preload("res://commands/gather_resource_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64

func _init() -> void:
	var failures: Array[String] = run_gather_test()
	if failures.is_empty():
		print("GATHER_TEST: PASS")
	else:
		print("GATHER_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


func run_gather_test() -> Array[String]:
	var failures: Array[String] = []

	var game_state: GameState = _create_initial_game_state()
	var command_buffer: CommandBuffer = CommandBufferClass.new()
	var replay_log: ReplayLog = ReplayLogClass.new()
	var state_hasher: StateHasher = StateHasherClass.new()
	var systems: Array[SimulationSystem] = []
	systems.append(BuildCommandSystemClass.new())
	systems.append(MoveCommandSystemClass.new())
	systems.append(GatherCommandSystemClass.new())
	systems.append(MovementSystemClass.new())
	systems.append(WorkerEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	var tick_manager: TickManager = TickManagerClass.new(
		game_state, command_buffer, replay_log, state_hasher, systems
	)

	# Find worker and resource IDs
	var worker_ids: Array[int] = game_state.get_entities_by_type("unit")
	var resource_ids: Array[int] = game_state.get_entities_by_type("resource_node")

	print("Workers: %s" % str(worker_ids))
	print("Resources: %s" % str(resource_ids))

	if worker_ids.is_empty():
		failures.append("No workers in initial state.")
		return failures
	if resource_ids.is_empty():
		failures.append("No resources in initial state.")
		return failures

	var worker_id: int = worker_ids[0]
	var resource_id: int = resource_ids[0]

	var worker_before: Dictionary = game_state.get_entity_dict(worker_id)
	var worker_cell_before: Vector2i = game_state.get_entity_grid_position(worker_before)
	print("Worker %d at %s, task=%s" % [worker_id, str(worker_cell_before), game_state.get_entity_task_state(worker_before)])

	# Issue gather command for ONE worker only (the regression case)
	var gather_cmd_single: GatherResourceCommand = GatherResourceCommandClass.new(0, 1, 0, worker_id, resource_id)
	tick_manager.queue_command(gather_cmd_single)

	print("--- Per-tick movement trace (single worker) ---")

	# Advance tick 0 (command processed here)
	tick_manager.advance_one_tick()

	var worker_after_t0: Dictionary = game_state.get_entity_dict(worker_id)
	var task_after_t0: String = game_state.get_entity_task_state(worker_after_t0)
	var has_move_target: bool = game_state.get_entity_bool(worker_after_t0, "has_move_target", false)
	var path_size: int = game_state.get_entity_path_cells(worker_after_t0).size()
	print("After tick 0: task=%s has_move_target=%s path_size=%d" % [task_after_t0, str(has_move_target), path_size])

	if task_after_t0 != "to_resource":
		failures.append("After gather command tick 0: expected task=to_resource, got task=%s" % task_after_t0)

	# Advance several more ticks and check worker moved
	for tick_i in range(10):
		tick_manager.advance_one_tick()
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		print("  tick %d: cell=%s task=%s traffic=%s path_size=%d" % [
			tick_i + 1,
			str(game_state.get_entity_grid_position(we)),
			game_state.get_entity_task_state(we),
			game_state.get_entity_string(we, "traffic_state", ""),
			game_state.get_entity_path_cells(we).size(),
		])

	var worker_after_t10: Dictionary = game_state.get_entity_dict(worker_id)
	var worker_cell_after: Vector2i = game_state.get_entity_grid_position(worker_after_t10)
	var task_after_t10: String = game_state.get_entity_task_state(worker_after_t10)
	print("After 10 more ticks: task=%s cell=%s" % [task_after_t10, str(worker_cell_after)])

	if worker_cell_after == worker_cell_before:
		failures.append("Worker did not move after 10 ticks (still at %s)" % str(worker_cell_before))

	return failures


func _create_initial_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": _build_blocked_cells(),
	}

	var stockpile_cell: Vector2i = Vector2i(2, 2)
	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = {
		"id": stockpile_id,
		"entity_type": "stockpile",
		"owner_id": 1,
		"grid_position": stockpile_cell,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var resource_cells: Array[Vector2i] = [Vector2i(15, 4), Vector2i(15, 5)]
	for resource_cell in resource_cells:
		var resource_node_id: int = state.allocate_entity_id()
		state.entities[resource_node_id] = {
			"id": resource_node_id,
			"entity_type": "resource_node",
			"resource_type": "wood",
			"grid_position": resource_cell,
			"remaining_amount": 80,
		}

	var starting_cells: Array[Vector2i] = [
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
	]
	for cell in starting_cells:
		var unit_id: int = state.allocate_entity_id()
		state.entities[unit_id] = {
			"id": unit_id,
			"entity_type": "unit",
			"unit_role": "worker",
			"owner_id": 1,
			"grid_position": cell,
			"move_target": cell,
			"path_cells": [],
			"has_move_target": false,
			"worker_task_state": "idle",
			"assigned_resource_node_id": 0,
			"assigned_stockpile_id": stockpile_id,
			"assigned_construction_site_id": 0,
			"carried_resource_type": "",
			"carried_amount": 0,
			"interaction_slot_cell": Vector2i(-1, -1),
			"traffic_state": "",
			"carry_capacity": 10,
			"harvest_amount": 5,
			"gather_duration_ticks": 8,
			"deposit_duration_ticks": 2,
			"gather_progress_ticks": 0,
		}
		state.occupancy["%d,%d" % [cell.x, cell.y]] = unit_id

	return state


func _build_blocked_cells() -> Dictionary:
	var blocked_cells: Dictionary = {}
	var cells: Array[Vector2i] = [
		Vector2i(2, 2),
		Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
		Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7),
		Vector2i(13, 8), Vector2i(13, 9),
		Vector2i(15, 4), Vector2i(15, 5),
	]
	for cell in cells:
		blocked_cells["%d,%d" % [cell.x, cell.y]] = true
	return blocked_cells
