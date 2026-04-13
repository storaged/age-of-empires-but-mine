extends SceneTree

## Headless test: verifies basic combat — soldier attacks and kills enemy.

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
const AttackCommandClass = preload("res://commands/attack_command.gd")
const MoveUnitCommandClass = preload("res://commands/move_unit_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_soldier_kills_enemy_test())
	failures.append_array(run_archer_attacks_from_range_test())
	failures.append_array(run_interrupt_and_idle_test())
	if failures.is_empty():
		print("COMBAT_TEST: PASS")
	else:
		print("COMBAT_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: soldier moves to enemy, attacks, kills it — enemy removed from entities.
func run_soldier_kills_enemy_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var soldier_id: int = game_state.get_entities_by_type("unit")[0]
	var enemy_ids: Array[int] = _get_enemy_ids(game_state)

	if enemy_ids.is_empty():
		failures.append("[kills] No enemy units in initial state.")
		return failures

	var enemy_id: int = enemy_ids[0]
	var attack_cmd := AttackCommandClass.new(0, 1, 0, soldier_id, enemy_id)
	tick_manager.queue_command(attack_cmd)

	# Enough ticks to travel + kill (hp=20, dmg=8, cooldown=4 → ~3 hits ~12 ticks + travel ~5)
	var killed: bool = false
	for _i in range(40):
		tick_manager.advance_one_tick()
		if not game_state.entities.has(enemy_id):
			killed = true
			print("[kills] Enemy killed at tick %d" % game_state.current_tick)
			break

	if not killed:
		var hp: int = game_state.get_entity_hp(game_state.get_entity_dict(enemy_id)) if game_state.entities.has(enemy_id) else -1
		failures.append("[kills] Enemy not killed after 40 ticks (hp=%d)" % hp)
		return failures

	var soldier: Dictionary = game_state.get_entity_dict(soldier_id)
	var task: String = game_state.get_entity_task_state(soldier)
	var target: int = game_state.get_entity_attack_target_id(soldier)
	if task != "idle":
		failures.append("[kills] Soldier task after kill: expected idle, got %s" % task)
	if target != 0:
		failures.append("[kills] Soldier attack_target_id not cleared after kill: %d" % target)

	return failures


## Test 2: attack interrupted by move command — soldier goes idle, no stale attack.
func run_archer_attacks_from_range_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = GameStateClass.new()
	game_state.resources = {"wood": 0, "stone": 0}
	game_state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": {},
	}

	var archer_id: int = game_state.allocate_entity_id()
	var archer_cell: Vector2i = Vector2i(6, 8)
	game_state.entities[archer_id] = GameDefinitionsClass.create_unit_entity(
		"archer",
		archer_id,
		1,
		archer_cell,
		0
	)
	game_state.occupancy[game_state.cell_key(archer_cell)] = archer_id

	var enemy_id: int = game_state.allocate_entity_id()
	var enemy_cell: Vector2i = Vector2i(9, 8)
	game_state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy",
		enemy_id,
		2,
		enemy_cell,
		0
	)
	game_state.occupancy[game_state.cell_key(enemy_cell)] = enemy_id

	var tick_manager: TickManager = _make_tick_manager(game_state)
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, archer_id, enemy_id))

	var killed: bool = false
	for _i in range(30):
		tick_manager.advance_one_tick()
		if not game_state.entities.has(enemy_id):
			killed = true
			break

	if not killed:
		failures.append("[archer_range] Archer failed to kill target from ranged attack flow.")
		return failures

	var archer: Dictionary = game_state.get_entity_dict(archer_id)
	if game_state.get_entity_grid_position(archer) != archer_cell:
		failures.append("[archer_range] Archer moved despite already being in range.")

	return failures


## Test 3: attack interrupted by move command — soldier goes idle, no stale attack.
func run_interrupt_and_idle_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _create_initial_game_state()
	var tick_manager: TickManager = _make_tick_manager(game_state)

	var soldier_id: int = game_state.get_entities_by_type("unit")[0]
	var enemy_ids: Array[int] = _get_enemy_ids(game_state)
	if enemy_ids.is_empty():
		failures.append("[interrupt] No enemies.")
		return failures

	var enemy_id: int = enemy_ids[0]

	# Attack command
	var attack_cmd := AttackCommandClass.new(0, 1, 0, soldier_id, enemy_id)
	tick_manager.queue_command(attack_cmd)
	for _i in range(5):
		tick_manager.advance_one_tick()

	var task_mid: String = game_state.get_entity_task_state(game_state.get_entity_dict(soldier_id))
	print("[interrupt] After 5 ticks: task=%s" % task_mid)

	# Move interrupt
	var move_cmd := MoveUnitCommandClass.new(game_state.current_tick, 1, 1, soldier_id, Vector2i(5, 5))
	tick_manager.queue_command(move_cmd)
	tick_manager.advance_one_tick()

	var soldier: Dictionary = game_state.get_entity_dict(soldier_id)
	var target_after: int = game_state.get_entity_attack_target_id(soldier)
	if target_after != 0:
		failures.append("[interrupt] attack_target_id not cleared by move: %d" % target_after)

	return failures


func _get_enemy_ids(game_state: GameState) -> Array[int]:
	var ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("unit"):
		var e: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(e) != 1:
			ids.append(entity_id)
	return ids


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
	state.resources = {"wood": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": {},
	}

	# One player soldier close to enemy
	var soldier_id: int = state.allocate_entity_id()
	var soldier_cell: Vector2i = Vector2i(10, 8)
	state.entities[soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier",
		soldier_id,
		1,
		soldier_cell,
		0
	)
	state.occupancy["10,8"] = soldier_id

	# One enemy dummy unit
	var enemy_id: int = state.allocate_entity_id()
	var enemy_cell: Vector2i = Vector2i(14, 8)
	state.entities[enemy_id] = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy",
		enemy_id,
		2,
		enemy_cell,
		0
	)
	state.occupancy["14,8"] = enemy_id

	return state
