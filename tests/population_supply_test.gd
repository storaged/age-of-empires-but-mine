extends SceneTree

const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_population_cap_gate_test())
	failures.append_array(run_house_supply_increase_test())
	failures.append_array(run_reserved_population_queue_test())
	if failures.is_empty():
		print("POPULATION_SUPPLY_TEST: PASS")
	else:
		print("POPULATION_SUPPLY_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_population_cap_gate_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_population_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var stockpile_id: int = 1

	if game_state.get_population_used(1) != 5:
		failures.append("[cap_gate] Expected 5 used population, got %d." % game_state.get_population_used(1))
	if game_state.get_population_cap(1) != 5:
		failures.append("[cap_gate] Expected base cap 5, got %d." % game_state.get_population_cap(1))

	tick_manager.queue_command(QueueProductionCommandClass.new(0, 1, 0, stockpile_id, "worker"))
	tick_manager.advance_one_tick()

	var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
	if game_state.get_entity_production_queue_count(stockpile_entity) != 0:
		failures.append("[cap_gate] Worker production queued even though cap was full.")

	return failures


func run_house_supply_increase_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_population_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var stockpile_id: int = 1
	var house_id: int = game_state.allocate_entity_id()

	game_state.entities[house_id] = {
		"id": house_id,
		"entity_type": "structure",
		"structure_type": "house",
		"owner_id": 1,
		"grid_position": Vector2i(6, 6),
		"is_constructed": true,
		"construction_progress_ticks": 24,
		"construction_duration_ticks": 24,
		"assigned_builder_id": 0,
	}

	if game_state.get_population_cap(1) != 10:
		failures.append("[house_supply] Expected house to raise cap to 10, got %d." % game_state.get_population_cap(1))

	tick_manager.queue_command(QueueProductionCommandClass.new(0, 1, 0, stockpile_id, "worker"))
	tick_manager.advance_one_tick()

	var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
	if game_state.get_entity_production_queue_count(stockpile_entity) != 1:
		failures.append("[house_supply] Worker production did not queue after supply increased.")

	return failures


func run_reserved_population_queue_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_population_test_state_with_worker_count(4)
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var stockpile_id: int = 1

	if game_state.get_population_used(1) != 4:
		failures.append("[reserved] Expected 4 living population, got %d." % game_state.get_population_used(1))

	tick_manager.queue_command(QueueProductionCommandClass.new(0, 1, 0, stockpile_id, "worker"))
	tick_manager.advance_one_tick()

	var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
	if game_state.get_entity_production_queue_count(stockpile_entity) != 1:
		failures.append("[reserved] First queued worker did not enter production queue.")
	if game_state.get_population_reserved(1) != 5:
		failures.append("[reserved] Expected reserved population 5 after first queue, got %d." % game_state.get_population_reserved(1))
	if game_state.get_population_queued(1) != 1:
		failures.append("[reserved] Expected queued population 1, got %d." % game_state.get_population_queued(1))

	tick_manager.queue_command(QueueProductionCommandClass.new(1, 1, 1, stockpile_id, "worker"))
	tick_manager.advance_one_tick()

	stockpile_entity = game_state.get_entity_dict(stockpile_id)
	if game_state.get_entity_production_queue_count(stockpile_entity) != 1:
		failures.append("[reserved] Second queued worker should be rejected at reserved cap.")

	return failures


func _make_tick_manager(game_state: GameState) -> TickManager:
	var command_buffer: CommandBuffer = CommandBufferClass.new()
	var replay_log: ReplayLog = ReplayLogClass.new()
	var state_hasher: StateHasher = StateHasherClass.new()
	var systems: Array[SimulationSystem] = []
	systems.append(BuildCommandSystemClass.new())
	systems.append(MoveCommandSystemClass.new())
	systems.append(GatherCommandSystemClass.new())
	systems.append(CombatSystemClass.new())
	systems.append(MovementSystemClass.new())
	systems.append(WorkerEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems, [])


func _create_population_test_state() -> GameState:
	return _create_population_test_state_with_worker_count(5)


func _create_population_test_state_with_worker_count(worker_count: int) -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 200, "stone": 0}
	state.map_data = {"width": 12, "height": 12, "cell_size": 64, "blocked_cells": {}}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = {
		"id": stockpile_id,
		"entity_type": "stockpile",
		"owner_id": 1,
		"grid_position": Vector2i(2, 2),
		"hp": 40,
		"max_hp": 40,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var worker_cells: Array[Vector2i] = [
		Vector2i(3, 2),
		Vector2i(3, 3),
		Vector2i(2, 3),
		Vector2i(4, 2),
		Vector2i(4, 3),
	]
	for i in range(mini(worker_count, worker_cells.size())):
		var worker_cell_value: Variant = worker_cells[i]
		if not (worker_cell_value is Vector2i):
			continue
		var worker_cell: Vector2i = worker_cell_value
		var worker_id: int = state.allocate_entity_id()
		state.entities[worker_id] = {
			"id": worker_id,
			"entity_type": "unit",
			"unit_role": "worker",
			"owner_id": 1,
			"grid_position": worker_cell,
			"move_target": worker_cell,
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
		state.occupancy[state.cell_key(worker_cell)] = worker_id

	return state
