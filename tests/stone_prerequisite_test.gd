extends SceneTree

## Headless tests: stone gathering, prerequisite gating, archery range production.

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
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
const GatherResourceCommandClass = preload("res://commands/gather_resource_command.gd")
const BuildStructureCommandClass = preload("res://commands/build_structure_command.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_stone_gather_test())
	failures.append_array(run_prerequisite_rejection_test())
	failures.append_array(run_prerequisite_chain_test())
	failures.append_array(run_archery_range_production_test())
	if failures.is_empty():
		print("STONE_PREREQUISITE_TEST: PASS")
	else:
		print("STONE_PREREQUISITE_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: worker gathers stone and deposits it into game_state.resources["stone"].
func run_stone_gather_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var worker_id: int = game_state.get_entities_by_type("unit")[0]
	var stone_node_id: int = _find_resource_node_by_type(game_state, "stone")
	if stone_node_id == 0:
		failures.append("[stone_gather] No stone node found.")
		return failures

	var gather_cmd := GatherResourceCommandClass.new(0, 1, 0, worker_id, stone_node_id)
	tick_manager.queue_command(gather_cmd)

	var stone_deposited: bool = false
	for _i in range(80):
		tick_manager.advance_one_tick()
		if game_state.get_resource_amount("stone") > 0:
			stone_deposited = true
			print("[stone_gather] Stone deposited at tick %d: %d" % [
				game_state.current_tick, game_state.get_resource_amount("stone")
			])
			break

	if not stone_deposited:
		failures.append("[stone_gather] Stone never deposited after 80 ticks.")

	return failures


## Test 2: building barracks without a house is rejected by BuildCommandSystem.
func run_prerequisite_rejection_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var worker_id: int = game_state.get_entities_by_type("unit")[0]

	# Give enough resources so only prerequisite blocks it.
	game_state.resources["wood"] = 200
	game_state.resources["stone"] = 200

	var initial_entity_count: int = game_state.entities.size()
	var build_cmd := BuildStructureCommandClass.new(0, 1, 0, worker_id, "barracks", Vector2i(6, 5))
	tick_manager.queue_command(build_cmd)
	tick_manager.advance_one_tick()

	if game_state.entities.size() > initial_entity_count:
		failures.append("[prereq_reject] Barracks was placed without a completed house.")
	else:
		print("[prereq_reject] Correctly rejected barracks with no house.")

	# Also verify prerequisite check helper directly.
	if game_state.is_prerequisite_met("barracks"):
		failures.append("[prereq_reject] is_prerequisite_met('barracks') returned true with no house.")

	if not game_state.is_prerequisite_met("house"):
		failures.append("[prereq_reject] is_prerequisite_met('house') returned false (house has no prereq).")

	return failures


## Test 3: barracks can be placed after house is fully constructed.
func run_prerequisite_chain_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	game_state.resources["wood"] = 200
	game_state.resources["stone"] = 200

	var worker_id: int = game_state.get_entities_by_type("unit")[0]

	# Build and complete a house directly in state.
	var house_id: int = game_state.allocate_entity_id()
	game_state.entities[house_id] = {
		"id": house_id,
		"entity_type": "structure",
		"structure_type": "house",
		"owner_id": 1,
		"grid_position": Vector2i(5, 5),
		"is_constructed": true,
		"construction_progress_ticks": 24,
		"construction_duration_ticks": 24,
		"assigned_builder_id": 0,
	}

	if not game_state.is_prerequisite_met("barracks"):
		failures.append("[prereq_chain] is_prerequisite_met('barracks') false even after house completed.")
		return failures
	print("[prereq_chain] Prerequisite met for barracks after house placed.")

	# Place barracks — should succeed.
	var initial_count: int = game_state.entities.size()
	var build_cmd := BuildStructureCommandClass.new(0, 1, 0, worker_id, "barracks", Vector2i(7, 5))
	tick_manager.queue_command(build_cmd)
	tick_manager.advance_one_tick()

	if game_state.entities.size() <= initial_count:
		failures.append("[prereq_chain] Barracks not placed despite completed house.")
	else:
		print("[prereq_chain] Barracks placed successfully.")

	# archery_range should still be blocked (no barracks completed yet).
	if game_state.is_prerequisite_met("archery_range"):
		failures.append("[prereq_chain] is_prerequisite_met('archery_range') true with only unbuilt barracks.")

	return failures


## Test 4: archery range (once built) can produce an archer.
func run_archery_range_production_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	game_state.resources["wood"] = 200
	game_state.resources["stone"] = 200

	# Inject a completed archery_range.
	var range_id: int = game_state.allocate_entity_id()
	var range_cell: Vector2i = Vector2i(6, 6)
	game_state.entities[range_id] = {
		"id": range_id,
		"entity_type": "structure",
		"structure_type": "archery_range",
		"owner_id": 1,
		"grid_position": range_cell,
		"is_constructed": true,
		"construction_progress_ticks": 35,
		"construction_duration_ticks": 35,
		"assigned_builder_id": 0,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var initial_unit_count: int = game_state.get_entities_by_type("unit").size()
	var produce_cmd := QueueProductionCommandClass.new(0, 1, 0, range_id, "archer")
	tick_manager.queue_command(produce_cmd)

	var wood_before: int = game_state.get_resource_amount("wood")
	var stone_before: int = game_state.get_resource_amount("stone")

	var archer_spawned: bool = false
	for _i in range(60):
		tick_manager.advance_one_tick()
		if game_state.get_entities_by_type("unit").size() > initial_unit_count:
			archer_spawned = true
			print("[archery_prod] Archer spawned at tick %d" % game_state.current_tick)
			break

	if not archer_spawned:
		failures.append("[archery_prod] Archer not spawned after 60 ticks.")
		return failures

	# Verify resources were deducted.
	var archer_costs: Dictionary = GameDefinitionsClass.get_unit_production_costs("archer")
	var expected_wood: int = wood_before - _get_cost(archer_costs, "wood")
	var expected_stone: int = stone_before - _get_cost(archer_costs, "stone")
	if game_state.get_resource_amount("wood") != expected_wood:
		failures.append("[archery_prod] Wood not deducted correctly: expected %d got %d" % [
			expected_wood, game_state.get_resource_amount("wood")
		])
	if game_state.get_resource_amount("stone") != expected_stone:
		failures.append("[archery_prod] Stone not deducted correctly: expected %d got %d" % [
			expected_stone, game_state.get_resource_amount("stone")
		])

	# Verify the spawned unit is an archer.
	var new_unit_ids: Array[int] = game_state.get_entities_by_type("unit")
	var found_archer: bool = false
	for unit_id in new_unit_ids:
		var unit_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_unit_role(unit_entity) == "archer":
			found_archer = true
			break
	if not found_archer:
		failures.append("[archery_prod] No entity with unit_role 'archer' found after spawn.")

	return failures


func _get_cost(costs: Dictionary, resource_type: String) -> int:
	if not costs.has(resource_type):
		return 0
	var val: Variant = costs[resource_type]
	return val if val is int else 0


func _find_resource_node_by_type(game_state: GameState, resource_type: String) -> int:
	for entity_id in game_state.get_entities_by_type("resource_node"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_resource_type(entity) == resource_type:
			return entity_id
	return 0


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


func _create_initial_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": {},
	}

	var stockpile_id: int = state.allocate_entity_id()
	var stockpile_cell: Vector2i = Vector2i(2, 2)
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

	# Stone node adjacent to worker start so test completes in reasonable ticks.
	var stone_id: int = state.allocate_entity_id()
	var stone_cell: Vector2i = Vector2i(6, 3)
	state.entities[stone_id] = {
		"id": stone_id,
		"entity_type": "resource_node",
		"resource_type": "stone",
		"grid_position": stone_cell,
		"remaining_amount": 60,
	}

	var worker_id: int = state.allocate_entity_id()
	var worker_cell: Vector2i = Vector2i(3, 3)
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
	state.occupancy["%d,%d" % [worker_cell.x, worker_cell.y]] = worker_id

	return state
