extends SceneTree

## Headless test: verifies construction start, interruption, and resume.

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
const AssignConstructionCommandClass = preload("res://commands/assign_construction_command.gd")
const GatherResourceCommandClass = preload("res://commands/gather_resource_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_construction_completes_test())
	failures.append_array(run_resume_after_interrupt_test())
	if failures.is_empty():
		print("CONSTRUCTION_TEST: PASS")
	else:
		print("CONSTRUCTION_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: worker assigned to pre-placed structure reaches it and completes construction.
func run_construction_completes_test() -> Array[String]:
	var failures: Array[String] = []

	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var worker_ids: Array[int] = game_state.get_entities_by_type("unit")
	var structure_ids: Array[int] = game_state.get_entities_by_type("structure")

	if worker_ids.is_empty():
		failures.append("[completes] No workers.")
		return failures
	if structure_ids.is_empty():
		failures.append("[completes] No structure.")
		return failures

	var worker_id: int = worker_ids[0]
	var structure_id: int = structure_ids[0]

	var assign_cmd := AssignConstructionCommandClass.new(
		0, 1, 0, worker_id, structure_id
	)
	tick_manager.queue_command(assign_cmd)

	# Advance enough ticks: path (~8 cells) + construction (24 ticks) + buffer
	var max_ticks: int = 60
	for _i in range(max_ticks):
		tick_manager.advance_one_tick()
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		if game_state.get_entity_is_constructed(structure_entity):
			print("[completes] Structure built at tick %d" % game_state.current_tick)
			return failures

	failures.append("[completes] Structure not built after %d ticks." % max_ticks)
	return failures


## Test 2: worker interrupted mid-construction, then resumed via AssignConstructionCommand.
func run_resume_after_interrupt_test() -> Array[String]:
	var failures: Array[String] = []

	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var worker_ids: Array[int] = game_state.get_entities_by_type("unit")
	var structure_ids: Array[int] = game_state.get_entities_by_type("structure")
	var resource_ids: Array[int] = game_state.get_entities_by_type("resource_node")

	if worker_ids.is_empty() or structure_ids.is_empty() or resource_ids.is_empty():
		failures.append("[resume] Missing worker, structure, or resource.")
		return failures

	var worker_id: int = worker_ids[0]
	var structure_id: int = structure_ids[0]
	var resource_id: int = resource_ids[0]

	# Assign to construction
	var assign_cmd := AssignConstructionCommandClass.new(
		0, 1, 0, worker_id, structure_id
	)
	tick_manager.queue_command(assign_cmd)

	# Let worker reach site and start constructing (at least 12 ticks)
	for _i in range(16):
		tick_manager.advance_one_tick()

	var worker_after_start: Dictionary = game_state.get_entity_dict(worker_id)
	var task_after_start: String = game_state.get_entity_task_state(worker_after_start)
	print("[resume] After 16 ticks: worker task=%s" % task_after_start)

	# Interrupt: redirect worker to gather
	var gather_cmd: GatherResourceCommand = GatherResourceCommandClass.new(
		game_state.current_tick + 1, 1, 1, worker_id, resource_id
	)
	tick_manager.queue_command(gather_cmd)
	tick_manager.advance_one_tick()

	var worker_after_interrupt: Dictionary = game_state.get_entity_dict(worker_id)
	var task_after_interrupt: String = game_state.get_entity_task_state(worker_after_interrupt)
	print("[resume] After interrupt: worker task=%s" % task_after_interrupt)

	var structure_mid: Dictionary = game_state.get_entity_dict(structure_id)
	var progress_mid: int = game_state.get_entity_construction_progress_ticks(structure_mid)
	print("[resume] Structure progress before resume: %d" % progress_mid)

	# Resume construction
	var resume_cmd := AssignConstructionCommandClass.new(
		game_state.current_tick + 1, 1, 2, worker_id, structure_id
	)
	tick_manager.queue_command(resume_cmd)

	# Advance enough ticks to finish
	var max_ticks: int = 60
	for _i in range(max_ticks):
		tick_manager.advance_one_tick()
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		if game_state.get_entity_is_constructed(structure_entity):
			var final_progress: int = game_state.get_entity_construction_progress_ticks(structure_entity)
			print("[resume] Structure built at tick %d (progress=%d)" % [game_state.current_tick, final_progress])
			if final_progress < progress_mid:
				failures.append("[resume] Progress regressed after resume (%d < %d)." % [final_progress, progress_mid])
			return failures

	failures.append("[resume] Structure not built after resume within %d ticks." % max_ticks)
	return failures


func _make_tick_manager(game_state: GameState) -> TickManager:
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
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems)


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

	# Pre-placed unfinished structure (no wood cost, already "started")
	var structure_cell: Vector2i = Vector2i(7, 3)
	var structure_id: int = state.allocate_entity_id()
	state.entities[structure_id] = {
		"id": structure_id,
		"entity_type": "structure",
		"structure_type": "house",
		"owner_id": 1,
		"grid_position": structure_cell,
		"is_constructed": false,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": 24,
		"assigned_builder_id": 0,
	}
	# Structure is a static blocker — add to blocked_cells via map_data
	state.map_data["blocked_cells"]["%d,%d" % [structure_cell.x, structure_cell.y]] = true

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
