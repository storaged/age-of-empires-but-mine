extends SceneTree

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const BuildCommandSystemClass = preload("res://simulation/systems/build_command_system.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const GatherCommandSystemClass = preload("res://simulation/systems/gather_command_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const ProductionSystemClass = preload("res://simulation/systems/production_system.gd")
const StructureEconomySystemClass = preload("res://simulation/systems/structure_economy_system.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_farm_generates_food_test())
	failures.append_array(run_food_gates_military_production_test())
	if failures.is_empty():
		print("FARM_FOOD_TEST: PASS")
	else:
		print("FARM_FOOD_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_farm_generates_food_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_food_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var interval: int = GameDefinitionsClass.get_structure_resource_trickle_interval_ticks("farm")
	var amount: int = GameDefinitionsClass.get_structure_resource_trickle_amount("farm")
	for _i in range(interval * 2):
		tick_manager.advance_one_tick()

	var expected_food: int = amount * 2
	if game_state.get_resource_amount("food") != expected_food:
		failures.append("[farm_income] Expected %d food after two farm payouts, got %d." % [
			expected_food,
			game_state.get_resource_amount("food"),
		])
	return failures


func run_food_gates_military_production_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_food_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)
	var barracks_id: int = 3

	tick_manager.queue_command(QueueProductionCommandClass.new(0, 1, 0, barracks_id, "soldier"))
	tick_manager.advance_one_tick()

	var barracks_entity: Dictionary = game_state.get_entity_dict(barracks_id)
	if game_state.get_entity_production_queue_count(barracks_entity) != 0:
		failures.append("[food_gate] Soldier production queued with zero food.")

	var soldier_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs("soldier")
	var food_needed: int = 0
	if soldier_costs.has("food"):
		var food_value: Variant = soldier_costs["food"]
		if food_value is int:
			food_needed = food_value
	for _i in range(food_needed * GameDefinitionsClass.get_structure_resource_trickle_interval_ticks("farm")):
		tick_manager.advance_one_tick()

	tick_manager.queue_command(QueueProductionCommandClass.new(game_state.current_tick, 1, 1, barracks_id, "soldier"))
	tick_manager.advance_one_tick()

	barracks_entity = game_state.get_entity_dict(barracks_id)
	if game_state.get_entity_production_queue_count(barracks_entity) != 1:
		failures.append("[food_gate] Soldier production did not queue after enough food accrued.")
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
	systems.append(StructureEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems, [])


func _create_food_test_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"food": 0, "wood": 200, "stone": 0}
	state.map_data = {"width": 12, "height": 12, "cell_size": 64, "blocked_cells": {}}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_stockpile_entity(
		stockpile_id,
		1,
		Vector2i(2, 2)
	)

	var farm_id: int = state.allocate_entity_id()
	state.entities[farm_id] = GameDefinitionsClass.create_structure_entity(
		"farm",
		farm_id,
		1,
		Vector2i(4, 2)
	)

	var barracks_id: int = state.allocate_entity_id()
	state.entities[barracks_id] = GameDefinitionsClass.create_structure_entity(
		"barracks",
		barracks_id,
		1,
		Vector2i(5, 2)
	)

	return state
