extends SceneTree

const MatchConfigClass = preload("res://simulation/match_config.gd")
const PrototypeGameplayScript = preload("res://scenes/prototype_gameplay.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const GameStateClass = preload("res://simulation/game_state.gd")
const ScenarioRuntimeClass = preload("res://simulation/scenario_runtime.gd")
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
const BuildStructureCommandClass = preload("res://commands/build_structure_command.gd")
const GatherResourceCommandClass = preload("res://commands/gather_resource_command.gd")
const MoveUnitCommandClass = preload("res://commands/move_unit_command.gd")
const AttackCommandClass = preload("res://commands/attack_command.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_safe_spawn_resolution_test())
	failures.append_array(run_scripted_spawn_resolution_test())
	failures.append_array(run_destroyed_stockpile_revalidation_test())
	failures.append_array(run_depleted_resource_revalidation_test())
	failures.append_array(run_invalid_construction_revalidation_test())
	failures.append_array(run_construction_stale_path_recovery_test())
	failures.append_array(run_worker_build_gather_contention_test())
	failures.append_array(run_reciprocal_worker_deadlock_test())
	failures.append_array(run_unreachable_move_intent_abandons_cleanly_test())
	failures.append_array(run_melee_attackers_pressure_structure_test())
	failures.append_array(run_idle_stockpile_blocker_vacates_test())
	failures.append_array(run_idle_service_cell_vacates_for_active_worker_test())
	if failures.is_empty():
		print("MOVEMENT_RECOVERY_TEST: PASS")
	else:
		print("MOVEMENT_RECOVERY_TEST: FAIL")
		for failure in failures:
			print("  FAIL: %s" % failure)
	quit()


func run_safe_spawn_resolution_test() -> Array[String]:
	var failures: Array[String] = []
	var cfg: MatchConfig = MatchConfigClass.new()
	cfg.map_width = 8
	cfg.map_height = 6
	cfg.blocked_cells = [Vector2i(2, 2), Vector2i(3, 2)]
	cfg.resource_nodes = [
		{"type": "wood", "cell": Vector2i(4, 2), "amount": 120},
	]
	cfg.player_start_structures = [
		{"structure_type": "stockpile", "cell": Vector2i(1, 1)},
	]
	cfg.enemy_start_structures = []
	cfg.player_start_units = [
		{"unit_type": "worker", "cell": Vector2i(2, 2)},
		{"unit_type": "worker", "cell": Vector2i(3, 2)},
		{"unit_type": "worker", "cell": Vector2i(4, 2)},
	]
	cfg.enemy_start_units = []
	var state: GameState = _build_state_from_config(cfg)
	var seen: Dictionary = {}
	for entity_id in state.get_entities_by_type("unit"):
		var entity: Dictionary = state.get_entity_dict(entity_id)
		var cell: Vector2i = state.get_entity_grid_position(entity)
		if state.is_cell_blocked(cell):
			failures.append("[spawn] Unit spawned on blocked/reserved cell %s." % str(cell))
		var key: String = state.cell_key(cell)
		if seen.has(key):
			failures.append("[spawn] Units spawned on overlapping cells %s." % key)
		seen[key] = true
	if seen.size() != 3:
		failures.append("[spawn] Expected all three start workers to resolve onto valid cells.")
	return failures


func run_scripted_spawn_resolution_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 6))
	state.entities[1] = GameDefinitionsClass.create_resource_node_entity("wood", 1, Vector2i(4, 2), 100)
	state.next_entity_id = 2
	state.map_data["blocked_cells"] = {state.cell_key(Vector2i(3, 2)): true}
	state.scenario_state = {
		"objectives": [],
		"events": [{
			"id": "spawn_test",
			"trigger": {"type": "tick_at_least", "tick": 0},
			"actions": [{
				"type": "spawn_units",
				"owner_id": 2,
				"unit_type": "soldier",
				"cells": [Vector2i(3, 2), Vector2i(4, 2)],
			}],
		}],
		"fired_event_ids": [],
		"alerts": [],
	}
	state.rebuild_static_blocker_cache()
	var tick_manager: TickManager = _make_tick_manager(state, true)
	tick_manager.advance_one_tick()
	var seen: Dictionary = {}
	for entity_id in state.get_entities_by_type("unit"):
		var entity: Dictionary = state.get_entity_dict(entity_id)
		if state.get_entity_owner_id(entity) != 2:
			continue
		var cell: Vector2i = state.get_entity_grid_position(entity)
		if state.map_data["blocked_cells"].has(state.cell_key(cell)):
			failures.append("[scripted_spawn] Spawn resolved onto blocked cell %s." % str(cell))
		if cell == Vector2i(4, 2):
			failures.append("[scripted_spawn] Spawn resolved onto resource cell.")
		var key: String = state.cell_key(cell)
		if seen.has(key):
			failures.append("[scripted_spawn] Scripted spawns overlapped on %s." % key)
		seen[key] = true
	if seen.size() != 2:
		failures.append("[scripted_spawn] Expected both scripted spawns to resolve.")
	return failures


func run_destroyed_stockpile_revalidation_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 6))
	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity("stockpile", stockpile_id, 1, Vector2i(1, 2), true, 0)
	var worker_id: int = state.allocate_entity_id()
	var worker: Dictionary = GameDefinitionsClass.create_unit_entity("worker", worker_id, 1, Vector2i(4, 2), stockpile_id)
	worker["assigned_stockpile_id"] = stockpile_id
	worker["worker_task_state"] = "to_stockpile"
	worker["carried_resource_type"] = "wood"
	worker["carried_amount"] = 5
	worker["interaction_slot_cell"] = Vector2i(2, 2)
	worker["move_target"] = Vector2i(2, 2)
	worker["has_move_target"] = true
	worker["path_cells"] = [Vector2i(3, 2), Vector2i(2, 2)]
	state.entities[worker_id] = worker
	state.occupancy[state.cell_key(Vector2i(4, 2))] = worker_id
	state.rebuild_static_blocker_cache()
	state.entities.erase(stockpile_id)
	state.rebuild_static_blocker_cache()
	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(6):
		tick_manager.advance_one_tick()
	var final_worker: Dictionary = state.get_entity_dict(worker_id)
	if state.get_entity_task_state(final_worker) == "to_stockpile" or state.get_entity_task_state(final_worker) == "depositing":
		failures.append("[stockpile_invalid] Worker kept stale delivery intent after stockpile vanished.")
	return failures


func run_depleted_resource_revalidation_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 6))
	var resource_id: int = state.allocate_entity_id()
	state.entities[resource_id] = GameDefinitionsClass.create_resource_node_entity("wood", resource_id, Vector2i(5, 2), 0)
	var worker_id: int = state.allocate_entity_id()
	var worker: Dictionary = GameDefinitionsClass.create_unit_entity("worker", worker_id, 1, Vector2i(2, 2), 0)
	worker["assigned_resource_node_id"] = resource_id
	worker["worker_task_state"] = "to_resource"
	worker["interaction_slot_cell"] = Vector2i(4, 2)
	worker["move_target"] = Vector2i(4, 2)
	worker["has_move_target"] = true
	worker["path_cells"] = [Vector2i(3, 2), Vector2i(4, 2)]
	state.entities[worker_id] = worker
	state.occupancy[state.cell_key(Vector2i(2, 2))] = worker_id
	state.rebuild_static_blocker_cache()
	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(4):
		tick_manager.advance_one_tick()
	var final_worker: Dictionary = state.get_entity_dict(worker_id)
	if state.get_entity_task_state(final_worker) == "to_resource" or state.get_entity_task_state(final_worker) == "gathering":
		failures.append("[resource_invalid] Worker kept stale resource intent after depletion.")
	return failures


func run_invalid_construction_revalidation_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 6))
	var structure_id: int = state.allocate_entity_id()
	state.entities[structure_id] = GameDefinitionsClass.create_structure_entity("house", structure_id, 1, Vector2i(4, 2), false, 0)
	var worker_id: int = state.allocate_entity_id()
	var worker: Dictionary = GameDefinitionsClass.create_unit_entity("worker", worker_id, 1, Vector2i(2, 2), 0)
	worker["assigned_construction_site_id"] = structure_id
	worker["worker_task_state"] = "to_construction"
	worker["interaction_slot_cell"] = Vector2i(3, 2)
	worker["move_target"] = Vector2i(3, 2)
	worker["has_move_target"] = true
	worker["path_cells"] = [Vector2i(3, 2)]
	state.entities[worker_id] = worker
	state.occupancy[state.cell_key(Vector2i(2, 2))] = worker_id
	state.rebuild_static_blocker_cache()
	state.entities.erase(structure_id)
	state.rebuild_static_blocker_cache()
	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(4):
		tick_manager.advance_one_tick()
	var final_worker: Dictionary = state.get_entity_dict(worker_id)
	if state.get_entity_task_state(final_worker) == "to_construction" or state.get_entity_task_state(final_worker) == "constructing":
		failures.append("[construction_invalid] Worker kept stale construction intent after site vanished.")
	return failures


func run_reciprocal_worker_deadlock_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(5, 5))
	state.resources = {"food": 0, "wood": 0, "stone": 0}
	for y in range(5):
		if y == 2:
			continue
		state.map_data["blocked_cells"][state.cell_key(Vector2i(2, y))] = true

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity("stockpile", stockpile_id, 1, Vector2i(0, 2), true, 0)
	var resource_id: int = state.allocate_entity_id()
	state.entities[resource_id] = GameDefinitionsClass.create_resource_node_entity("wood", resource_id, Vector2i(4, 2), 100)

	var deliverer_id: int = state.allocate_entity_id()
	var deliverer: Dictionary = GameDefinitionsClass.create_unit_entity("worker", deliverer_id, 1, Vector2i(2, 2), stockpile_id)
	deliverer["assigned_stockpile_id"] = stockpile_id
	deliverer["worker_task_state"] = "to_stockpile"
	deliverer["carried_resource_type"] = "wood"
	deliverer["carried_amount"] = 5
	deliverer["interaction_slot_cell"] = Vector2i(1, 2)
	deliverer["move_target"] = Vector2i(1, 2)
	deliverer["has_move_target"] = true
	deliverer["path_cells"] = [Vector2i(1, 2)]
	state.entities[deliverer_id] = deliverer
	state.occupancy[state.cell_key(Vector2i(2, 2))] = deliverer_id

	var gatherer_id: int = state.allocate_entity_id()
	var gatherer: Dictionary = GameDefinitionsClass.create_unit_entity("worker", gatherer_id, 1, Vector2i(1, 2), stockpile_id)
	gatherer["assigned_resource_node_id"] = resource_id
	gatherer["assigned_stockpile_id"] = stockpile_id
	gatherer["worker_task_state"] = "to_resource"
	gatherer["interaction_slot_cell"] = Vector2i(3, 2)
	gatherer["move_target"] = Vector2i(3, 2)
	gatherer["has_move_target"] = true
	gatherer["path_cells"] = [Vector2i(2, 2), Vector2i(3, 2)]
	state.entities[gatherer_id] = gatherer
	state.occupancy[state.cell_key(Vector2i(1, 2))] = gatherer_id
	state.rebuild_static_blocker_cache()

	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(20):
		tick_manager.advance_one_tick()

	var final_deliverer: Dictionary = state.get_entity_dict(deliverer_id)
	var final_gatherer: Dictionary = state.get_entity_dict(gatherer_id)
	if state.get_entity_carried_amount(final_deliverer) > 0 and state.get_entity_task_state(final_deliverer) == "to_stockpile":
		failures.append("[reciprocal] Deliver worker stayed stuck in reciprocal deadlock.")
	if state.get_entity_task_state(final_gatherer) == "to_resource" and state.get_entity_grid_position(final_gatherer).x <= 1:
		failures.append("[reciprocal] Gather worker failed to recover after yielding path.")
	return failures


func run_unreachable_move_intent_abandons_cleanly_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(6, 6))
	state.resources = {"food": 0, "wood": 0, "stone": 0}
	for x in range(6):
		state.map_data["blocked_cells"][state.cell_key(Vector2i(x, 3))] = true
	var unit_id: int = state.allocate_entity_id()
	var unit: Dictionary = GameDefinitionsClass.create_unit_entity("soldier", unit_id, 1, Vector2i(1, 1), 0)
	unit["worker_task_state"] = "to_rally"
	unit["move_target"] = Vector2i(4, 4)
	unit["has_move_target"] = true
	unit["path_cells"] = []
	state.entities[unit_id] = unit
	state.occupancy[state.cell_key(Vector2i(1, 1))] = unit_id
	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(12):
		tick_manager.advance_one_tick()
	var final_unit: Dictionary = state.get_entity_dict(unit_id)
	if state.get_entity_has_move_target(final_unit):
		failures.append("[stale_loop] Unreachable rally/move intent kept looping forever.")
	return failures


func run_construction_stale_path_recovery_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 5))
	state.resources = {"food": 0, "wood": 200, "stone": 0}

	var builder_id: int = state.allocate_entity_id()
	state.entities[builder_id] = GameDefinitionsClass.create_unit_entity("worker", builder_id, 1, Vector2i(2, 1), 0)
	state.occupancy[state.cell_key(Vector2i(2, 1))] = builder_id
	var mover_id: int = state.allocate_entity_id()
	state.entities[mover_id] = GameDefinitionsClass.create_unit_entity("worker", mover_id, 1, Vector2i(1, 2), 0)
	state.occupancy[state.cell_key(Vector2i(1, 2))] = mover_id

	var tick_manager: TickManager = _make_tick_manager(state, false)
	tick_manager.queue_command(MoveUnitCommandClass.new(0, 1, 0, mover_id, Vector2i(6, 2)))
	tick_manager.queue_command(BuildStructureCommandClass.new(1, 1, 0, builder_id, "house", Vector2i(3, 2)))

	for _i in range(20):
		tick_manager.advance_one_tick()

	var mover: Dictionary = state.get_entity_dict(mover_id)
	var mover_cell: Vector2i = state.get_entity_grid_position(mover)
	if mover_cell.x < 5:
		failures.append("[stale_path] Unit failed to recover around reserved construction footprint.")
	return failures


func run_worker_build_gather_contention_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(9, 6))
	state.resources = {"food": 0, "wood": 200, "stone": 0}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity(
		"stockpile",
		stockpile_id,
		1,
		Vector2i(0, 2),
		true,
		0
	)
	var builder_id: int = state.allocate_entity_id()
	state.entities[builder_id] = GameDefinitionsClass.create_unit_entity("worker", builder_id, 1, Vector2i(1, 1), stockpile_id)
	state.occupancy[state.cell_key(Vector2i(1, 1))] = builder_id
	var gatherer_id: int = state.allocate_entity_id()
	state.entities[gatherer_id] = GameDefinitionsClass.create_unit_entity("worker", gatherer_id, 1, Vector2i(1, 2), stockpile_id)
	state.occupancy[state.cell_key(Vector2i(1, 2))] = gatherer_id
	var resource_id: int = state.allocate_entity_id()
	state.entities[resource_id] = GameDefinitionsClass.create_resource_node_entity("wood", resource_id, Vector2i(6, 2), 200)
	state.rebuild_static_blocker_cache()

	var tick_manager: TickManager = _make_tick_manager(state, false)
	tick_manager.queue_command(BuildStructureCommandClass.new(0, 1, 0, builder_id, "house", Vector2i(3, 2)))
	tick_manager.queue_command(GatherResourceCommandClass.new(0, 1, 0, gatherer_id, resource_id))

	for _i in range(40):
		tick_manager.advance_one_tick()

	var gatherer: Dictionary = state.get_entity_dict(gatherer_id)
	var task_state: String = state.get_entity_task_state(gatherer)
	if task_state == "idle" and state.get_entity_carried_amount(gatherer) == 0:
		failures.append("[build_gather] Gather worker never recovered from local construction contention.")
	return failures


func run_melee_attackers_pressure_structure_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(12, 12))
	state.resources = {"food": 0, "wood": 0, "stone": 0}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity(
		"stockpile",
		stockpile_id,
		1,
		Vector2i(6, 6),
		true,
		0
	)

	var attacker_cells: Array[Vector2i] = [
		Vector2i(1, 6),
		Vector2i(1, 5),
		Vector2i(1, 7),
		Vector2i(2, 6),
	]
	var attacker_ids: Array[int] = []
	for attacker_cell in attacker_cells:
		var attacker_id: int = state.allocate_entity_id()
		attacker_ids.append(attacker_id)
		state.entities[attacker_id] = GameDefinitionsClass.create_unit_entity(
			"soldier",
			attacker_id,
			2,
			attacker_cell,
			0
		)
		state.occupancy[state.cell_key(attacker_cell)] = attacker_id

	state.rebuild_static_blocker_cache()
	var initial_hp: int = state.get_entity_hp(state.get_entity_dict(stockpile_id))
	var tick_manager: TickManager = _make_tick_manager(state, false)
	for attacker_id in attacker_ids:
		tick_manager.queue_command(AttackCommandClass.new(0, 2, attacker_id, attacker_id, stockpile_id))

	for _i in range(70):
		tick_manager.advance_one_tick()
		if not state.entities.has(stockpile_id):
			break

	if state.entities.has(stockpile_id):
		var remaining_hp: int = state.get_entity_hp(state.get_entity_dict(stockpile_id))
		if remaining_hp >= initial_hp:
			failures.append("[melee] Attackers stayed jammed and never damaged the stockpile.")
	return failures


func run_idle_stockpile_blocker_vacates_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(8, 6))
	state.resources = {"food": 0, "wood": 0, "stone": 0}
	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity(
		"stockpile",
		stockpile_id,
		1,
		Vector2i(1, 2),
		true,
		0
	)

	var idle_id: int = state.allocate_entity_id()
	state.entities[idle_id] = GameDefinitionsClass.create_unit_entity("worker", idle_id, 1, Vector2i(2, 2), stockpile_id)
	state.occupancy[state.cell_key(Vector2i(2, 2))] = idle_id

	var deliverer_id: int = state.allocate_entity_id()
	var deliverer: Dictionary = GameDefinitionsClass.create_unit_entity("worker", deliverer_id, 1, Vector2i(5, 2), stockpile_id)
	deliverer["assigned_stockpile_id"] = stockpile_id
	deliverer["worker_task_state"] = "to_stockpile"
	deliverer["carried_resource_type"] = "wood"
	deliverer["carried_amount"] = 5
	deliverer["interaction_slot_cell"] = Vector2i(2, 2)
	deliverer["move_target"] = Vector2i(2, 2)
	deliverer["has_move_target"] = true
	deliverer["path_cells"] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)]
	state.entities[deliverer_id] = deliverer
	state.occupancy[state.cell_key(Vector2i(5, 2))] = deliverer_id
	state.rebuild_static_blocker_cache()

	var tick_manager: TickManager = _make_tick_manager(state, false)
	for _i in range(20):
		tick_manager.advance_one_tick()

	var final_idle: Dictionary = state.get_entity_dict(idle_id)
	var final_deliverer: Dictionary = state.get_entity_dict(deliverer_id)
	if state.get_entity_grid_position(final_idle) == Vector2i(2, 2):
		failures.append("[service_stockpile] Idle blocker never vacated stockpile service cell.")
	if state.get_entity_carried_amount(final_deliverer) > 0:
		failures.append("[service_stockpile] Deliver worker failed to complete deposit after idle blocker.")
	return failures


func run_idle_service_cell_vacates_for_active_worker_test() -> Array[String]:
	var failures: Array[String] = []
	var state: GameState = _create_empty_state(Vector2i(10, 6))
	state.resources = {"food": 0, "wood": 200, "stone": 0}

	var stockpile_id: int = state.allocate_entity_id()
	state.entities[stockpile_id] = GameDefinitionsClass.create_structure_entity(
		"stockpile",
		stockpile_id,
		1,
		Vector2i(0, 2),
		true,
		0
	)

	var builder_id: int = state.allocate_entity_id()
	state.entities[builder_id] = GameDefinitionsClass.create_unit_entity("worker", builder_id, 1, Vector2i(1, 1), stockpile_id)
	state.occupancy[state.cell_key(Vector2i(1, 1))] = builder_id

	var idle_id: int = state.allocate_entity_id()
	state.entities[idle_id] = GameDefinitionsClass.create_unit_entity("worker", idle_id, 1, Vector2i(4, 2), stockpile_id)
	state.occupancy[state.cell_key(Vector2i(4, 2))] = idle_id

	var gatherer_id: int = state.allocate_entity_id()
	var gatherer: Dictionary = GameDefinitionsClass.create_unit_entity("worker", gatherer_id, 1, Vector2i(2, 2), stockpile_id)
	state.entities[gatherer_id] = gatherer
	state.occupancy[state.cell_key(Vector2i(2, 2))] = gatherer_id

	var resource_id: int = state.allocate_entity_id()
	state.entities[resource_id] = GameDefinitionsClass.create_resource_node_entity("wood", resource_id, Vector2i(7, 2), 150)
	state.rebuild_static_blocker_cache()

	var tick_manager: TickManager = _make_tick_manager(state, false)
	tick_manager.queue_command(BuildStructureCommandClass.new(0, 1, 0, builder_id, "house", Vector2i(5, 2)))
	tick_manager.queue_command(GatherResourceCommandClass.new(0, 1, 0, gatherer_id, resource_id))
	for _i in range(36):
		tick_manager.advance_one_tick()

	var final_idle: Dictionary = state.get_entity_dict(idle_id)
	var final_gatherer: Dictionary = state.get_entity_dict(gatherer_id)
	if state.get_entity_grid_position(final_idle) == Vector2i(4, 2):
		failures.append("[service_local] Idle unit never vacated active service lane.")
	var final_task_state: String = state.get_entity_task_state(final_gatherer)
	if final_task_state == "idle" and state.get_entity_carried_amount(final_gatherer) == 0:
		failures.append("[service_local] Gather worker failed to recover after idle service-cell blocker.")
	return failures


func _build_state_from_config(cfg: MatchConfig) -> GameState:
	var gameplay: Node2D = PrototypeGameplayScript.new()
	gameplay.set_match_config(cfg)
	var state: GameState = gameplay._create_initial_game_state()
	gameplay.queue_free()
	state.rebuild_static_blocker_cache()
	return state


func _create_empty_state(size: Vector2i) -> GameState:
	var state: GameState = GameStateClass.new()
	state.map_data = {
		"width": size.x,
		"height": size.y,
		"cell_size": 64,
		"blocked_cells": {},
	}
	return state


func _make_tick_manager(game_state: GameState, include_scenario_runtime: bool) -> TickManager:
	var systems: Array[SimulationSystem] = []
	systems.append(BuildCommandSystemClass.new())
	systems.append(MoveCommandSystemClass.new())
	systems.append(GatherCommandSystemClass.new())
	systems.append(CombatSystemClass.new())
	systems.append(MovementSystemClass.new())
	systems.append(WorkerEconomySystemClass.new())
	systems.append(ProductionSystemClass.new())
	if include_scenario_runtime:
		systems.append(ScenarioRuntimeClass.new())
	return TickManagerClass.new(
		game_state,
		CommandBufferClass.new(),
		ReplayLogClass.new(),
		StateHasherClass.new(),
		systems
	)
