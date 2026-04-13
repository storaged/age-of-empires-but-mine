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
const MoveUnitCommandClass = preload("res://commands/move_unit_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_idle_blocker_repath_test())
	if failures.is_empty():
		print("CONGESTION_RECOVERY_TEST: PASS")
	else:
		print("CONGESTION_RECOVERY_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_idle_blocker_repath_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = GameStateClass.new()
	game_state.resources = {"wood": 0, "stone": 0}
	game_state.map_data = {"width": 8, "height": 5, "cell_size": 64, "blocked_cells": {}}

	var moving_id: int = game_state.allocate_entity_id()
	var blocker_id: int = game_state.allocate_entity_id()
	game_state.entities[moving_id] = GameDefinitionsClass.create_unit_entity(
		"worker",
		moving_id,
		1,
		Vector2i(1, 2),
		0
	)
	game_state.entities[blocker_id] = GameDefinitionsClass.create_unit_entity(
		"worker",
		blocker_id,
		1,
		Vector2i(2, 2),
		0
	)
	game_state.occupancy[game_state.cell_key(Vector2i(1, 2))] = moving_id
	game_state.occupancy[game_state.cell_key(Vector2i(2, 2))] = blocker_id

	var tick_manager: TickManager = _make_tick_manager(game_state)
	tick_manager.queue_command(MoveUnitCommandClass.new(0, 1, 0, moving_id, Vector2i(6, 2)))

	var progressed: bool = false
	for _i in range(12):
		tick_manager.advance_one_tick()
		var moving_entity: Dictionary = game_state.get_entity_dict(moving_id)
		var current_cell: Vector2i = game_state.get_entity_grid_position(moving_entity)
		if current_cell != Vector2i(1, 2):
			progressed = true
		if current_cell.x >= 3:
			break

	if not progressed:
		failures.append("[idle_blocker] Unit never recovered from simple line congestion.")
		return failures

	var final_entity: Dictionary = game_state.get_entity_dict(moving_id)
	var final_cell: Vector2i = game_state.get_entity_grid_position(final_entity)
	if final_cell.x < 3:
		failures.append("[idle_blocker] Unit failed to repath around idle blocker.")

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
