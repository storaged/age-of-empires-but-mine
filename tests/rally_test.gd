extends SceneTree

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")
const SetRallyPointCommandClass = preload("res://commands/set_rally_point_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_worker_resource_rally_test())
	failures.append_array(run_cell_rally_improves_spawn_throughput_test())
	if failures.is_empty():
		print("RALLY_TEST: PASS")
	else:
		print("RALLY_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_worker_resource_rally_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_base_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var stockpile_id: int = 1
	var tree_id: int = 2

	tick_manager.queue_command(
		SetRallyPointCommandClass.new(0, 1, 0, stockpile_id, "resource", Vector2i(5, 2), tree_id)
	)
	tick_manager.queue_command(
		QueueProductionCommandClass.new(0, 1, 1, stockpile_id, "worker")
	)

	var rallied_worker_id: int = 0
	for _i in range(80):
		tick_manager.advance_one_tick()
		rallied_worker_id = _find_latest_player_worker(game_state, stockpile_id)
		if game_state.get_resource_amount("wood") > 80:
			break

	if rallied_worker_id == 0:
		failures.append("[resource_rally] No worker spawned from stockpile.")
		return failures

	var worker_entity: Dictionary = game_state.get_entity_dict(rallied_worker_id)
	if game_state.get_entity_assigned_resource_node_id(worker_entity) != tree_id:
		failures.append("[resource_rally] Spawned worker did not inherit resource rally target.")
	if game_state.get_resource_amount("wood") <= 80:
		failures.append("[resource_rally] Resource rally did not convert into deposited wood.")

	return failures


func run_cell_rally_improves_spawn_throughput_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_tight_spawn_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var stockpile_id: int = 1

	tick_manager.queue_command(
		SetRallyPointCommandClass.new(0, 1, 0, stockpile_id, "cell", Vector2i(4, 2), 0)
	)
	tick_manager.queue_command(
		QueueProductionCommandClass.new(0, 1, 1, stockpile_id, "worker")
	)
	tick_manager.queue_command(
		QueueProductionCommandClass.new(0, 1, 2, stockpile_id, "worker")
	)

	for _i in range(50):
		tick_manager.advance_one_tick()

	var worker_count: int = 0
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) == 1 and game_state.get_entity_unit_role(entity) == "worker":
			worker_count += 1

	if worker_count < 2:
		failures.append("[cell_rally] Cell rally did not allow second worker to spawn through tight exit.")

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
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems)


func _create_base_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 100, "stone": 0}
	state.map_data = {"width": 10, "height": 10, "cell_size": 64, "blocked_cells": {}}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_stockpile_entity(
		stockpile_id,
		1,
		Vector2i(2, 2)
	)

	var tree_id: int = state.allocate_entity_id()
	state.entities[tree_id] = GameDefinitionsClass.create_resource_node_entity(
		"wood",
		tree_id,
		Vector2i(5, 2),
		40
	)

	return state


func _create_tight_spawn_state() -> GameState:
	var state: GameState = _create_base_state()
	state.resources = {"wood": 100, "stone": 0}
	state.map_data["blocked_cells"] = {
		state.cell_key(Vector2i(1, 2)): true,
		state.cell_key(Vector2i(2, 1)): true,
		state.cell_key(Vector2i(2, 3)): true,
		state.cell_key(Vector2i(1, 1)): true,
		state.cell_key(Vector2i(1, 3)): true,
		state.cell_key(Vector2i(3, 1)): true,
		state.cell_key(Vector2i(3, 3)): true,
	}
	return state


func _find_latest_player_worker(game_state: GameState, producer_id: int) -> int:
	var latest_worker_id: int = 0
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != 1:
			continue
		if game_state.get_entity_unit_role(entity) != "worker":
			continue
		if game_state.get_entity_assigned_stockpile_id(entity) != producer_id:
			continue
		if entity_id > latest_worker_id:
			latest_worker_id = entity_id
	return latest_worker_id
