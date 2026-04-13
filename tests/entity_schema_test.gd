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
const AttackCommandClass = preload("res://commands/attack_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_worker_and_structure_schema_test())
	failures.append_array(run_worker_is_damageable_test())
	if failures.is_empty():
		print("ENTITY_SCHEMA_TEST: PASS")
	else:
		print("ENTITY_SCHEMA_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_worker_and_structure_schema_test() -> Array[String]:
	var failures: Array[String] = []
	var worker: Dictionary = GameDefinitionsClass.create_unit_entity("worker", 1, 1, Vector2i(2, 2), 99)
	var stockpile: Dictionary = GameDefinitionsClass.create_stockpile_entity(2, 1, Vector2i(1, 1))
	var house: Dictionary = GameDefinitionsClass.create_structure_entity("house", 3, 1, Vector2i(4, 4), false, 1)
	var tree: Dictionary = GameDefinitionsClass.create_resource_node_entity("wood", 4, Vector2i(6, 6))

	if worker.is_empty() or int(worker.get("hp", 0)) <= 0 or int(worker.get("max_hp", 0)) <= 0:
		failures.append("[schema] Worker missing normalized hp/max_hp.")
	if int(worker.get("attack_damage", -1)) != 0:
		failures.append("[schema] Worker expected non-combat default attack_damage 0.")
	if int(worker.get("attack_range_cells", -1)) != 0:
		failures.append("[schema] Worker expected attack_range_cells 0.")
	if int(worker.get("population_cost", -1)) != 1:
		failures.append("[schema] Worker missing normalized population_cost.")

	var archer: Dictionary = GameDefinitionsClass.create_unit_entity("archer", 5, 1, Vector2i(3, 3), 2)
	if int(archer.get("attack_range_cells", 0)) <= 1:
		failures.append("[schema] Archer missing normalized ranged attack_range_cells.")

	if stockpile.is_empty() or str(stockpile.get("structure_type", "")) != "stockpile":
		failures.append("[schema] Stockpile missing normalized structure_type.")
	if int(stockpile.get("hp", 0)) <= 0 or int(stockpile.get("max_hp", 0)) <= 0:
		failures.append("[schema] Stockpile missing normalized hp/max_hp.")
	if str(stockpile.get("rally_mode", "missing")) == "missing":
		failures.append("[schema] Stockpile missing normalized rally_mode.")
	if int(stockpile.get("rally_target_id", -1)) < 0:
		failures.append("[schema] Stockpile missing normalized rally_target_id.")

	if house.is_empty() or int(house.get("supply_provided", -1)) < 0:
		failures.append("[schema] House missing normalized supply_provided.")
	if bool(house.get("is_constructed", true)):
		failures.append("[schema] House test entity should remain unconstructed.")

	if tree.is_empty() or not bool(tree.get("is_gatherable", false)):
		failures.append("[schema] Resource node missing normalized gatherable flag.")
	if bool(tree.get("is_depleted", true)):
		failures.append("[schema] Fresh resource node incorrectly marked depleted.")

	return failures


func run_worker_is_damageable_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = GameStateClass.new()
	game_state.resources = {"wood": 0, "stone": 0}
	game_state.map_data = {"width": 10, "height": 10, "cell_size": 64, "blocked_cells": {}}

	var soldier_id: int = game_state.allocate_entity_id()
	var worker_id: int = game_state.allocate_entity_id()
	game_state.entities[soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		soldier_id,
		1,
		Vector2i(3, 3),
		0
	)
	game_state.entities[worker_id] = GameDefinitionsClass.create_unit_entity(
		"worker",
		worker_id,
		2,
		Vector2i(5, 3),
		0
	)
	game_state.occupancy[game_state.cell_key(Vector2i(3, 3))] = soldier_id
	game_state.occupancy[game_state.cell_key(Vector2i(5, 3))] = worker_id

	var tick_manager: TickManager = _make_tick_manager(game_state)
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, soldier_id, worker_id))

	var worker_killed: bool = false
	for _i in range(40):
		tick_manager.advance_one_tick()
		if not game_state.entities.has(worker_id):
			worker_killed = true
			break

	if not worker_killed:
		failures.append("[worker_damage] Soldier did not kill worker through generic combat flow.")

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
