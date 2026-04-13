extends SceneTree

const EnemyAIControllerClass = preload("res://simulation/enemy_ai_controller.gd")
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
	failures.append_array(run_enemy_ai_pacing_test())
	failures.append_array(run_enemy_ai_production_and_attack_test())
	failures.append_array(run_enemy_ai_uses_generic_combat_producer_test())
	failures.append_array(run_win_condition_test())
	failures.append_array(run_lose_condition_test())
	if failures.is_empty():
		print("AI_WINLOSE_TEST: PASS")
	else:
		print("AI_WINLOSE_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_enemy_ai_pacing_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_ai_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state, true)
	var barracks_id: int = _find_enemy_barracks_id(game_state)

	for _i in range(EnemyAIControllerClass.PRODUCTION_START_TICK):
		tick_manager.advance_one_tick()

	var barracks_entity: Dictionary = game_state.get_entity_dict(barracks_id)
	if game_state.get_entity_production_queue_count(barracks_entity) != 0:
		failures.append("[pacing] Enemy queued production before production start tick.")

	for _i in range(maxi(EnemyAIControllerClass.ATTACK_START_TICK - game_state.current_tick - 5, 0)):
		tick_manager.advance_one_tick()

	var enemy_soldier_id: int = _find_enemy_soldier_id(game_state)
	if enemy_soldier_id != 0:
		var enemy_soldier: Dictionary = game_state.get_entity_dict(enemy_soldier_id)
		if game_state.get_entity_attack_target_id(enemy_soldier) != 0:
			failures.append("[pacing] Enemy attacker received attack order before attack start tick.")

	return failures


func run_enemy_ai_production_and_attack_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_ai_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state, true)

	var barracks_id: int = _find_enemy_barracks_id(game_state)
	for _i in range(EnemyAIControllerClass.PRODUCTION_START_TICK + 2):
		tick_manager.advance_one_tick()
	var barracks_entity: Dictionary = game_state.get_entity_dict(barracks_id)
	if game_state.get_entity_production_queue_count(barracks_entity) <= 0:
		failures.append("[ai] Enemy AI did not queue production at the first production threshold.")
		return failures

	var produced_soldier_id: int = 0
	for _i in range(EnemyAIControllerClass.PRODUCTION_INTERVAL_TICKS):
		tick_manager.advance_one_tick()
		produced_soldier_id = _find_enemy_soldier_id(game_state)
		if produced_soldier_id != 0:
			break

	if produced_soldier_id == 0:
		failures.append("[ai] Enemy barracks did not produce a soldier.")
		return failures

	if game_state.current_tick < EnemyAIControllerClass.ATTACK_START_TICK:
		for _i in range(EnemyAIControllerClass.ATTACK_START_TICK - game_state.current_tick + 2):
			tick_manager.advance_one_tick()
	else:
		tick_manager.advance_one_tick()

	for _i in range(2):
		tick_manager.advance_one_tick()

	var soldier_entity: Dictionary = game_state.get_entity_dict(produced_soldier_id)
	if game_state.get_entity_attack_target_id(soldier_entity) == 0:
		failures.append("[ai] Produced enemy soldier did not receive an attack command.")

	return failures


func run_enemy_ai_uses_generic_combat_producer_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_ai_test_state("archery_range")
	var tick_manager: TickManager = _make_tick_manager(game_state, true)

	for _i in range(EnemyAIControllerClass.PRODUCTION_START_TICK + 2):
		tick_manager.advance_one_tick()

	var produced_archer_id: int = 0
	for _i in range(EnemyAIControllerClass.PRODUCTION_INTERVAL_TICKS + 30):
		tick_manager.advance_one_tick()
		produced_archer_id = _find_enemy_unit_by_role(game_state, "archer")
		if produced_archer_id != 0:
			break

	if produced_archer_id == 0:
		failures.append("[ai_generic] Enemy AI did not use archery_range to produce an archer.")
		return failures

	if game_state.current_tick < EnemyAIControllerClass.ATTACK_START_TICK:
		for _i in range(EnemyAIControllerClass.ATTACK_START_TICK - game_state.current_tick + 2):
			tick_manager.advance_one_tick()

	var archer_entity: Dictionary = game_state.get_entity_dict(produced_archer_id)
	if game_state.get_entity_attack_target_id(archer_entity) == 0:
		failures.append("[ai_generic] Enemy-produced archer did not receive an attack command.")

	return failures


func run_win_condition_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_winlose_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state, false)

	var player_soldier_id: int = 3
	var enemy_base_id: int = 2
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, player_soldier_id, enemy_base_id))

	for _i in range(30):
		tick_manager.advance_one_tick()
		if game_state.win_condition_met:
			break

	if not game_state.win_condition_met:
		failures.append("[win] Enemy base destruction did not set win_condition_met.")
	if game_state.lose_condition_met:
		failures.append("[win] lose_condition_met was set during win test.")
	return failures


func run_lose_condition_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_winlose_test_state()
	var tick_manager: TickManager = _make_tick_manager(game_state, false)

	var enemy_soldier_id: int = 4
	var player_stockpile_id: int = 1
	tick_manager.queue_command(AttackCommandClass.new(0, 2, 0, enemy_soldier_id, player_stockpile_id))

	for _i in range(30):
		tick_manager.advance_one_tick()
		if game_state.lose_condition_met:
			break

	if not game_state.lose_condition_met:
		failures.append("[lose] Player stockpile destruction did not set lose_condition_met.")
	if game_state.win_condition_met:
		failures.append("[lose] win_condition_met was set during lose test.")
	return failures


func _make_tick_manager(game_state: GameState, include_ai: bool) -> TickManager:
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
	var controllers: Array[RefCounted] = []
	if include_ai:
		controllers.append(EnemyAIControllerClass.new())
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems, controllers)


func _create_ai_test_state(enemy_producer_type: String = "barracks") -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0}
	state.map_data = {"width": 12, "height": 12, "cell_size": 64, "blocked_cells": {}}

	var player_stockpile_id: int = state.allocate_entity_id()
	state.entities[player_stockpile_id] = {
		"id": player_stockpile_id,
		"entity_type": "stockpile",
		"owner_id": 1,
		"grid_position": Vector2i(1, 1),
		"hp": 40,
		"max_hp": 40,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var enemy_base_id: int = state.allocate_entity_id()
	state.entities[enemy_base_id] = {
		"id": enemy_base_id,
		"entity_type": "structure",
		"structure_type": "enemy_base",
		"owner_id": 2,
		"grid_position": Vector2i(10, 10),
		"is_constructed": true,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": 0,
		"assigned_builder_id": 0,
		"hp": 50,
		"max_hp": 50,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var enemy_barracks_id: int = state.allocate_entity_id()
	state.entities[enemy_barracks_id] = {
		"id": enemy_barracks_id,
		"entity_type": "structure",
		"structure_type": enemy_producer_type,
		"owner_id": 2,
		"grid_position": Vector2i(9, 10),
		"is_constructed": true,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": 0,
		"assigned_builder_id": 0,
		"hp": 40,
		"max_hp": 40,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}
	return state


func _create_winlose_test_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0}
	state.map_data = {"width": 10, "height": 10, "cell_size": 64, "blocked_cells": {}}

	var player_stockpile_id: int = state.allocate_entity_id()
	state.entities[player_stockpile_id] = {
		"id": player_stockpile_id,
		"entity_type": "stockpile",
		"owner_id": 1,
		"grid_position": Vector2i(2, 2),
		"hp": 8,
		"max_hp": 8,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var enemy_base_id: int = state.allocate_entity_id()
	state.entities[enemy_base_id] = {
		"id": enemy_base_id,
		"entity_type": "structure",
		"structure_type": "enemy_base",
		"owner_id": 2,
		"grid_position": Vector2i(7, 2),
		"is_constructed": true,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": 0,
		"assigned_builder_id": 0,
		"hp": 8,
		"max_hp": 8,
		"production_queue_count": 0,
		"production_progress_ticks": 0,
		"production_duration_ticks": 0,
		"produced_unit_type": "",
		"production_blocked": false,
	}

	var player_soldier_id: int = state.allocate_entity_id()
	state.entities[player_soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		player_soldier_id,
		1,
		Vector2i(5, 2),
		player_stockpile_id
	)
	state.occupancy[state.cell_key(Vector2i(5, 2))] = player_soldier_id

	var enemy_soldier_id: int = state.allocate_entity_id()
	state.entities[enemy_soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		enemy_soldier_id,
		2,
		Vector2i(4, 2),
		enemy_base_id
	)
	state.occupancy[state.cell_key(Vector2i(4, 2))] = enemy_soldier_id

	return state


func _find_enemy_barracks_id(game_state: GameState) -> int:
	for structure_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		if game_state.get_entity_owner_id(structure_entity) != 2:
			continue
		if game_state.get_entity_structure_type(structure_entity) == "barracks":
			return structure_id
	return 0


func _find_enemy_soldier_id(game_state: GameState) -> int:
	return _find_enemy_unit_by_role(game_state, "soldier")


func _find_enemy_unit_by_role(game_state: GameState, unit_role: String) -> int:
	for unit_id in game_state.get_entities_by_type("unit"):
		var unit_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_owner_id(unit_entity) != 2:
			continue
		if game_state.get_entity_unit_role(unit_entity) == unit_role:
			return unit_id
	return 0
