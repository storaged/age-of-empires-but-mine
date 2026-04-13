extends SceneTree

## Headless tests: damage multiplier table and combat counter bonuses.

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const CombatSystemClass = preload("res://simulation/systems/combat_system.gd")
const MoveCommandSystemClass = preload("res://simulation/systems/move_command_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")
const CommandBufferClass = preload("res://runtime/command_buffer.gd")
const ReplayLogClass = preload("res://runtime/replay_log.gd")
const StateHasherClass = preload("res://runtime/state_hasher.gd")
const TickManagerClass = preload("res://runtime/tick_manager.gd")
const AttackCommandClass = preload("res://commands/attack_command.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_multiplier_table_test())
	failures.append_array(run_counter_label_test())
	failures.append_array(run_archer_counter_bonus_test())
	failures.append_array(run_soldier_counter_bonus_test())
	failures.append_array(run_neutral_matchup_test())
	if failures.is_empty():
		print("COMBAT_COUNTER_TEST: PASS")
	else:
		print("COMBAT_COUNTER_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: get_damage_multiplier API returns correct values from table.
func run_multiplier_table_test() -> Array[String]:
	var failures: Array[String] = []
	var cases: Array[Array] = [
		["archer", "soldier", 150],
		["archer", "worker", 125],
		["soldier", "worker", 150],
		["soldier", "archer", 125],
		["soldier", "soldier", 100],
		["archer", "archer", 100],
		["soldier", "enemy_dummy", 100],
		["archer", "enemy_dummy", 100],
		["worker", "soldier", 100],
		["", "soldier", 100],
	]
	for c in cases:
		var attacker_role: String = str(c[0])
		var target_role: String = str(c[1])
		var expected: int = int(c[2])
		var got: int = GameDefinitionsClass.get_damage_multiplier(attacker_role, target_role)
		if got != expected:
			failures.append("[table] get_damage_multiplier(%s, %s): expected %d got %d" % [
				attacker_role, target_role, expected, got
			])
	return failures


## Test 2: get_counter_label returns useful human-readable strings.
func run_counter_label_test() -> Array[String]:
	var failures: Array[String] = []
	var archer_label: String = GameDefinitionsClass.get_counter_label("archer")
	var soldier_label: String = GameDefinitionsClass.get_counter_label("soldier")
	var worker_label: String = GameDefinitionsClass.get_counter_label("worker")

	if "soldiers" not in archer_label:
		failures.append("[label] archer counter label missing 'soldiers': got '%s'" % archer_label)
	if "workers" not in archer_label:
		failures.append("[label] archer counter label missing 'workers': got '%s'" % archer_label)
	if "workers" not in soldier_label:
		failures.append("[label] soldier counter label missing 'workers': got '%s'" % soldier_label)
	if "archers" not in soldier_label:
		failures.append("[label] soldier counter label missing 'archers': got '%s'" % soldier_label)
	if worker_label != "":
		failures.append("[label] worker should have no counter label, got '%s'" % worker_label)

	print("[label] archer: %s" % archer_label)
	print("[label] soldier: %s" % soldier_label)
	return failures


## Test 3: archer deals counter bonus damage vs soldier.
## Archer base dmg=5, multiplier vs soldier=150 → 7 dmg.
## Set soldier HP=7: archer kills in one hit. Without counter, 5 dmg would not kill.
func run_archer_counter_bonus_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	var archer_id: int = game_state.allocate_entity_id()
	var archer_cell: Vector2i = Vector2i(5, 5)
	game_state.entities[archer_id] = GameDefinitionsClass.create_unit_entity(
		"archer", archer_id, 1, archer_cell, 0
	)
	game_state.occupancy[game_state.cell_key(archer_cell)] = archer_id

	var soldier_id: int = game_state.allocate_entity_id()
	var soldier_cell: Vector2i = Vector2i(7, 5)  # distance 2, within archer range 3
	var soldier_entity: Dictionary = GameDefinitionsClass.create_unit_entity(
		"soldier", soldier_id, 2, soldier_cell, 0
	)
	soldier_entity["hp"] = 7   # Would survive 1 hit of flat 5 dmg, dies to 7 dmg
	soldier_entity["max_hp"] = 7
	game_state.entities[soldier_id] = soldier_entity
	game_state.occupancy[game_state.cell_key(soldier_cell)] = soldier_id

	var tick_manager: TickManager = _make_combat_tick_manager(game_state)
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, archer_id, soldier_id))

	var killed: bool = false
	for _i in range(20):
		tick_manager.advance_one_tick()
		if not game_state.entities.has(soldier_id):
			killed = true
			print("[archer_counter] Soldier (7 HP) killed at tick %d" % game_state.current_tick)
			break

	if not killed:
		var hp_left: int = game_state.get_entity_hp(game_state.get_entity_dict(soldier_id)) if game_state.entities.has(soldier_id) else -1
		failures.append("[archer_counter] Soldier (7 HP) not killed within 20 ticks (hp=%d). Counter bonus may not be applied." % hp_left)
	return failures


## Test 4: soldier deals counter bonus damage vs worker.
## Soldier base dmg=8, multiplier vs worker=150 → 12 dmg.
## Set worker HP=10: soldier kills in one hit. Without counter, 8 dmg would not kill.
func run_soldier_counter_bonus_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	var soldier_id: int = game_state.allocate_entity_id()
	var soldier_cell: Vector2i = Vector2i(5, 5)
	game_state.entities[soldier_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", soldier_id, 1, soldier_cell, 0
	)
	game_state.occupancy[game_state.cell_key(soldier_cell)] = soldier_id

	var worker_id: int = game_state.allocate_entity_id()
	var worker_cell: Vector2i = Vector2i(6, 5)  # distance 1, within soldier melee range 1
	var worker_entity: Dictionary = GameDefinitionsClass.create_unit_entity(
		"worker", worker_id, 2, worker_cell, 0
	)
	worker_entity["hp"] = 10   # Survives flat 8 dmg, dies to 12 dmg
	worker_entity["max_hp"] = 10
	game_state.entities[worker_id] = worker_entity
	game_state.occupancy[game_state.cell_key(worker_cell)] = worker_id

	var tick_manager: TickManager = _make_combat_tick_manager(game_state)
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, soldier_id, worker_id))

	var killed: bool = false
	for _i in range(15):
		tick_manager.advance_one_tick()
		if not game_state.entities.has(worker_id):
			killed = true
			print("[soldier_counter] Worker (10 HP) killed at tick %d" % game_state.current_tick)
			break

	if not killed:
		var hp_left: int = game_state.get_entity_hp(game_state.get_entity_dict(worker_id)) if game_state.entities.has(worker_id) else -1
		failures.append("[soldier_counter] Worker (10 HP) not killed within 15 ticks (hp=%d). Counter bonus may not be applied." % hp_left)
	return failures


## Test 5: neutral matchup (soldier vs soldier) applies no bonus.
## Soldier base dmg=8, multiplier vs soldier=100 → 8 dmg.
## Set target soldier HP=9: survives 1 hit (flat 8 dmg), not killed prematurely.
func run_neutral_matchup_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	var attacker_id: int = game_state.allocate_entity_id()
	var attacker_cell: Vector2i = Vector2i(5, 5)
	game_state.entities[attacker_id] = GameDefinitionsClass.create_unit_entity(
		"soldier", attacker_id, 1, attacker_cell, 0
	)
	game_state.occupancy[game_state.cell_key(attacker_cell)] = attacker_id

	var target_id: int = game_state.allocate_entity_id()
	var target_cell: Vector2i = Vector2i(6, 5)  # distance 1, within melee range 1
	var target_entity: Dictionary = GameDefinitionsClass.create_unit_entity(
		"soldier", target_id, 2, target_cell, 0
	)
	target_entity["hp"] = 9
	target_entity["max_hp"] = 9
	game_state.entities[target_id] = target_entity
	game_state.occupancy[game_state.cell_key(target_cell)] = target_id

	var tick_manager: TickManager = _make_combat_tick_manager(game_state)
	tick_manager.queue_command(AttackCommandClass.new(0, 1, 0, attacker_id, target_id))

	# Run enough ticks for exactly one attack (cooldown=4, so 4 ticks safe)
	for _i in range(4):
		tick_manager.advance_one_tick()

	if not game_state.entities.has(target_id):
		failures.append("[neutral] Soldier (9 HP) was killed — expected to survive with 1 HP (8 flat dmg, no bonus).")
	else:
		var hp_left: int = game_state.get_entity_hp(game_state.get_entity_dict(target_id))
		if hp_left != 1:
			failures.append("[neutral] Soldier expected 1 HP after one hit (9-8=1), got %d HP." % hp_left)
		else:
			print("[neutral] Soldier correctly has 1 HP after flat 8 dmg hit (no bonus).")

	return failures


func _make_bare_game_state() -> GameState:
	var state: GameState = GameStateClass.new()
	state.resources = {"wood": 0, "stone": 0, "food": 0}
	state.map_data = {
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"cell_size": CELL_SIZE,
		"blocked_cells": {},
	}
	return state


func _make_combat_tick_manager(game_state: GameState) -> TickManager:
	var command_buffer: CommandBuffer = CommandBufferClass.new()
	var replay_log: ReplayLog = ReplayLogClass.new()
	var state_hasher: StateHasher = StateHasherClass.new()
	var systems: Array[SimulationSystem] = []
	systems.append(MoveCommandSystemClass.new())
	systems.append(CombatSystemClass.new())
	systems.append(MovementSystemClass.new())
	return TickManagerClass.new(game_state, command_buffer, replay_log, state_hasher, systems)
