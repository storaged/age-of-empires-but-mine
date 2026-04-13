extends SceneTree

## Headless tests: attack-move command behavior.
## Covers:
##   1. Attack-move command sets unit to attack_moving state
##   2. Unit in attack_moving acquires enemy in attack range and fights
##   3. After target dies unit resumes attack_moving toward destination
##   4. Unit with no enemies en route simply arrives at destination (idle)
##   5. MoveUnitCommand cancels attack_move_target_cell

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const AttackMoveCommandClass = preload("res://commands/attack_move_command.gd")
const MoveUnitCommandClass = preload("res://commands/move_unit_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const PLAYER_ID: int = 1
const ENEMY_ID: int = 2


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_attack_move_sets_state_test())
	failures.append_array(run_attack_move_acquires_enemy_test())
	failures.append_array(run_attack_move_resumes_after_kill_test())
	failures.append_array(run_attack_move_no_enemies_arrives_test())
	failures.append_array(run_move_cancels_attack_move_test())
	if failures.is_empty():
		print("ATTACK_MOVE_TEST: PASS")
	else:
		print("ATTACK_MOVE_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: AttackMoveCommand sets unit to attack_moving with correct destination.
func run_attack_move_sets_state_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var combat_system: CombatSystem = CombatSystemClass.new()

	var soldier_id: int = _add_soldier(game_state, Vector2i(3, 5))
	var dest: Vector2i = Vector2i(15, 5)
	var cmd: AttackMoveCommand = AttackMoveCommandClass.new(0, PLAYER_ID, 0, soldier_id, dest)

	combat_system.apply(game_state, [cmd], 0)

	var entity: Dictionary = game_state.get_entity_dict(soldier_id)
	var task: String = game_state.get_entity_task_state(entity)
	var stored_dest: Vector2i = Vector2i(-1, -1)
	if entity.has("attack_move_target_cell") and entity["attack_move_target_cell"] is Vector2i:
		stored_dest = entity["attack_move_target_cell"]

	if task != "attack_moving":
		failures.append("[state] Expected task=attack_moving after command, got %s" % task)
	if stored_dest != dest:
		failures.append("[state] Expected attack_move_target_cell=%s, got %s" % [dest, stored_dest])

	print("[state] task=%s dest=%s" % [task, stored_dest])
	return failures


## Test 2: In attack_moving, unit acquires nearest enemy within attack range.
## Soldier at (5,5) attack_range=1. Enemy at (6,5) — dist 1.
func run_attack_move_acquires_enemy_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var combat_system: CombatSystem = CombatSystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var soldier_id: int = _add_soldier(game_state, Vector2i(5, 5))
	var enemy_id: int = _add_enemy(game_state, Vector2i(6, 5))
	var dest: Vector2i = Vector2i(15, 5)
	var cmd: AttackMoveCommand = AttackMoveCommandClass.new(0, PLAYER_ID, 0, soldier_id, dest)
	combat_system.apply(game_state, [cmd], 0)

	# One tick: should acquire enemy since dist=1 is within attack_range=1
	combat_system.apply(game_state, [], 1)

	var entity: Dictionary = game_state.get_entity_dict(soldier_id)
	var task: String = game_state.get_entity_task_state(entity)
	var acquired_target: int = game_state.get_entity_attack_target_id(entity)

	if task != "to_target" and task != "attacking":
		failures.append("[acquire] Expected task=to_target or attacking after enemy in range, got %s" % task)
	if acquired_target != enemy_id:
		failures.append("[acquire] Expected attack_target_id=%d, got %d" % [enemy_id, acquired_target])

	print("[acquire] task=%s target=%d" % [task, acquired_target])
	return failures


## Test 3: After killing enemy, unit resumes attack_moving toward destination.
## Soldier at (5,5), enemy at (6,5) with 1 HP (dies in one hit).
## After kill, task should return to attack_moving.
func run_attack_move_resumes_after_kill_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var combat_system: CombatSystem = CombatSystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var soldier_id: int = _add_soldier(game_state, Vector2i(5, 5))
	var enemy_id: int = _add_enemy(game_state, Vector2i(6, 5), 1)  # 1 HP, dies in one hit
	var dest: Vector2i = Vector2i(15, 5)
	var cmd: AttackMoveCommand = AttackMoveCommandClass.new(0, PLAYER_ID, 0, soldier_id, dest)
	combat_system.apply(game_state, [cmd], 0)

	# Run ticks until enemy is gone or max ticks exceeded.
	var resumed: bool = false
	for tick in range(20):
		combat_system.apply(game_state, [], tick)
		movement_system.apply(game_state, [], tick)
		if not game_state.entities.has(enemy_id):
			# Enemy killed. Check next tick for resume.
			combat_system.apply(game_state, [], tick + 1)
			var entity: Dictionary = game_state.get_entity_dict(soldier_id)
			var task: String = game_state.get_entity_task_state(entity)
			if task == "attack_moving":
				resumed = true
			break

	if not resumed:
		var entity: Dictionary = game_state.get_entity_dict(soldier_id)
		failures.append("[resume] Expected attack_moving after kill, got task=%s, enemy_exists=%s" % [
			game_state.get_entity_task_state(entity), str(game_state.entities.has(enemy_id))
		])

	print("[resume] unit resumed attack_moving after kill: %s" % resumed)
	return failures


## Test 4: Unit with no enemies en route reaches destination and becomes idle.
func run_attack_move_no_enemies_arrives_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var combat_system: CombatSystem = CombatSystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var soldier_id: int = _add_soldier(game_state, Vector2i(3, 5))
	var dest: Vector2i = Vector2i(8, 5)
	var cmd: AttackMoveCommand = AttackMoveCommandClass.new(0, PLAYER_ID, 0, soldier_id, dest)
	combat_system.apply(game_state, [cmd], 0)

	var arrived_idle: bool = false
	for tick in range(30):
		combat_system.apply(game_state, [], tick)
		movement_system.apply(game_state, [], tick)
		var entity: Dictionary = game_state.get_entity_dict(soldier_id)
		var task: String = game_state.get_entity_task_state(entity)
		var cell: Vector2i = game_state.get_entity_grid_position(entity)
		if cell == dest and task == "idle":
			arrived_idle = true
			break

	if not arrived_idle:
		var entity: Dictionary = game_state.get_entity_dict(soldier_id)
		failures.append("[arrive] Unit should arrive at %s idle within 30 ticks (task=%s cell=%s)" % [
			dest, game_state.get_entity_task_state(entity), game_state.get_entity_grid_position(entity)
		])

	print("[arrive] soldier arrived idle at dest: %s" % arrived_idle)
	return failures


## Test 5: MoveUnitCommand cancels attack_move_target_cell.
func run_move_cancels_attack_move_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var combat_system: CombatSystem = CombatSystemClass.new()
	var move_system: MoveCommandSystem = MoveCommandSystemClass.new()

	var soldier_id: int = _add_soldier(game_state, Vector2i(3, 5))

	# Issue attack-move first
	var atk_cmd: AttackMoveCommand = AttackMoveCommandClass.new(0, PLAYER_ID, 0, soldier_id, Vector2i(15, 5))
	combat_system.apply(game_state, [atk_cmd], 0)

	var after_atk: Dictionary = game_state.get_entity_dict(soldier_id)
	if game_state.get_entity_task_state(after_atk) != "attack_moving":
		failures.append("[cancel] Setup failed — expected attack_moving before cancel test")

	# Override with plain MoveUnitCommand
	var move_cmd: MoveUnitCommand = MoveUnitCommandClass.new(1, PLAYER_ID, 1, soldier_id, Vector2i(5, 5))
	move_system.apply(game_state, [move_cmd], 1)

	var after_move: Dictionary = game_state.get_entity_dict(soldier_id)
	var stored_dest: Vector2i = Vector2i(-1, -1)
	if after_move.has("attack_move_target_cell") and after_move["attack_move_target_cell"] is Vector2i:
		stored_dest = after_move["attack_move_target_cell"]

	if stored_dest != Vector2i(-1, -1):
		failures.append("[cancel] MoveUnitCommand should clear attack_move_target_cell, got %s" % stored_dest)

	print("[cancel] attack_move_target_cell after MoveUnitCommand: %s" % stored_dest)
	return failures


## ── helpers ──────────────────────────────────────────────────────────────────


func _make_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0, "food": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": 64,
		"blocked_cells": {},
	}
	return state


func _add_soldier(game_state: GameState, cell: Vector2i) -> int:
	var id: int = game_state.allocate_entity_id()
	game_state.entities[id] = GameDefinitionsClass.create_unit_entity(
		"soldier", id, PLAYER_ID, cell, 0
	)
	game_state.occupancy[game_state.cell_key(cell)] = id
	return id


func _add_enemy(game_state: GameState, cell: Vector2i, hp: int = 30) -> int:
	var id: int = game_state.allocate_entity_id()
	var entity: Dictionary = GameDefinitionsClass.create_unit_entity(
		"enemy_dummy", id, ENEMY_ID, cell, 0
	)
	entity["hp"] = hp
	game_state.entities[id] = entity
	game_state.occupancy[game_state.cell_key(cell)] = id
	return id
