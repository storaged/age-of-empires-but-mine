extends SceneTree

## Headless tests: worker deposit / interaction robustness.
## Covers the three fixes in Phase 27:
##   1. Missing write-back after _reassign_stockpile_slot (primary bug)
##   2. Adjacent-position acceptance (worker already next to target)
##   3. Slot fallback when primary slot path is blocked

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const WorkerEconomySystemClass = preload("res://simulation/systems/worker_economy_system.gd")
const MovementSystemClass = preload("res://simulation/systems/movement_system.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const OWNER_ID: int = 1


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_write_back_deposit_test())
	failures.append_array(run_adjacent_slot_deposit_test())
	failures.append_array(run_fallback_slot_deposit_test())
	failures.append_array(run_write_back_resource_test())
	if failures.is_empty():
		print("WORKER_DEPOSIT_ROBUSTNESS_TEST: PASS")
	else:
		print("WORKER_DEPOSIT_ROBUSTNESS_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: write-back fix — reassign result must persist across ticks.
## Worker is in to_stockpile with empty path and NOT at interaction_slot_cell.
## Without the write-back fix, reassign is silently lost every tick and the
## worker stalls forever. With the fix, the new path is stored and the worker
## eventually deposits.
func run_write_back_deposit_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var economy_system: WorkerEconomySystem = WorkerEconomySystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	# Stockpile at (5,5). Worker at (5,9) — far, carrying 5 wood.
	# Set interaction_slot_cell to (5,4) — opposite side; worker will need a real path.
	var stockpile_id: int = _add_stockpile(game_state, Vector2i(5, 5))
	var worker_id: int = _add_worker_carrying(
		game_state, Vector2i(5, 9), stockpile_id, Vector2i(5, 4), "to_stockpile"
	)

	# Simulate up to 30 ticks — worker should deposit within that window.
	var deposited: bool = false
	for _tick in range(30):
		economy_system.apply(game_state, [], _tick)
		movement_system.apply(game_state, [], _tick)
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		var task: String = game_state.get_entity_task_state(we)
		if task == "depositing" or (task == "to_resource" and game_state.get_resource_amount("wood") > 0):
			deposited = true
			break

	if not deposited:
		var wood: int = game_state.get_resource_amount("wood")
		failures.append("[write_back] Worker should have deposited within 30 ticks (wood=%d)" % wood)

	print("[write_back] worker deposited: %s (wood=%d)" % [deposited, game_state.get_resource_amount("wood")])
	return failures


## Test 2: adjacent-position acceptance — worker already next to stockpile.
## Worker is at (5,6), stockpile at (5,5), but interaction_slot_cell = (4,5).
## With the adjacent fix, the worker immediately uses (5,6) as the slot and deposits.
## Without the fix, it reroutes to (4,5) unnecessarily, and if that path also fails
## due to the missing write-back, stalls forever.
func run_adjacent_slot_deposit_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var economy_system: WorkerEconomySystem = WorkerEconomySystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var stockpile_id: int = _add_stockpile(game_state, Vector2i(5, 5))
	# Worker at (5,6) — directly adjacent to stockpile. Slot assigned to wrong side.
	var worker_id: int = _add_worker_carrying(
		game_state, Vector2i(5, 6), stockpile_id, Vector2i(4, 5), "to_stockpile"
	)
	game_state.occupancy[game_state.cell_key(Vector2i(5, 6))] = worker_id

	# Should deposit within just a few ticks since worker is already adjacent.
	var deposited: bool = false
	for _tick in range(8):
		economy_system.apply(game_state, [], _tick)
		movement_system.apply(game_state, [], _tick)
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		var task: String = game_state.get_entity_task_state(we)
		if task == "depositing" or (task == "to_resource" and game_state.get_resource_amount("wood") > 0):
			deposited = true
			break

	if not deposited:
		failures.append("[adjacent] Worker adjacent to stockpile should deposit within 8 ticks")

	print("[adjacent] adjacent worker deposited: %s (wood=%d)" % [deposited, game_state.get_resource_amount("wood")])
	return failures


## Test 3: slot fallback — primary slot is fully blocked, another is open.
## Stockpile at (10,5). Cells (9,5), (10,4), (10,6) are terrain-blocked.
## Only (11,5) is reachable. Worker assigned to primary slot (9,5) which is blocked.
## With fallback, worker should find (11,5) and deposit successfully.
func run_fallback_slot_deposit_test() -> Array[String]:
	var failures: Array[String] = []
	# Stockpile at (10,5). Block three of four adjacent cells.
	var game_state: GameState = _make_game_state_with_blocked(
		[Vector2i(9, 5), Vector2i(10, 4), Vector2i(10, 6)]
	)
	var economy_system: WorkerEconomySystem = WorkerEconomySystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var stockpile_id: int = _add_stockpile(game_state, Vector2i(10, 5))
	# Worker at (5,5), far left. Primary slot (9,5) is terrain-blocked — unreachable.
	var worker_id: int = _add_worker_carrying(
		game_state, Vector2i(5, 5), stockpile_id, Vector2i(9, 5), "to_stockpile"
	)

	var deposited: bool = false
	for _tick in range(30):
		economy_system.apply(game_state, [], _tick)
		movement_system.apply(game_state, [], _tick)
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		var task: String = game_state.get_entity_task_state(we)
		if task == "depositing" or (task == "to_resource" and game_state.get_resource_amount("wood") > 0):
			deposited = true
			break

	if not deposited:
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		failures.append("[fallback] Worker should deposit via fallback slot (11,5) within 30 ticks (task=%s)" % game_state.get_entity_task_state(we))

	print("[fallback] fallback-slot worker deposited: %s (wood=%d)" % [deposited, game_state.get_resource_amount("wood")])
	return failures


## Test 4: same write-back fix applies to to_resource state (gather side).
## Worker is in to_resource with empty path and wrong slot. Must repath and gather.
func run_write_back_resource_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_game_state()
	var economy_system: WorkerEconomySystem = WorkerEconomySystemClass.new()
	var movement_system: MovementSystem = MovementSystemClass.new()

	var stockpile_id: int = _add_stockpile(game_state, Vector2i(2, 2))
	var resource_id: int = _add_resource_node(game_state, Vector2i(15, 5))
	# Worker at (10,5), assigned to resource node, slot on far side (15,4).
	# Empty path forces reassign. Write-back fix must persist the new path.
	var worker_id: int = _add_worker_to_resource(
		game_state, Vector2i(10, 5), resource_id, stockpile_id, Vector2i(15, 4)
	)

	var reached_resource: bool = false
	for _tick in range(30):
		economy_system.apply(game_state, [], _tick)
		movement_system.apply(game_state, [], _tick)
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		var task: String = game_state.get_entity_task_state(we)
		if task == "gathering":
			reached_resource = true
			break

	if not reached_resource:
		var we: Dictionary = game_state.get_entity_dict(worker_id)
		failures.append("[resource_wb] Worker should reach resource and start gathering within 30 ticks (task=%s)" % game_state.get_entity_task_state(we))

	print("[resource_wb] worker reached resource: %s" % reached_resource)
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


func _make_game_state_with_blocked(blocked_cells: Array[Vector2i]) -> GameState:
	var state: GameState = _make_game_state()
	for cell in blocked_cells:
		state.map_data["blocked_cells"][state.cell_key(cell)] = true
	return state


func _add_stockpile(game_state: GameState, cell: Vector2i) -> int:
	var id: int = game_state.allocate_entity_id()
	game_state.entities[id] = GameDefinitionsClass.create_stockpile_entity(id, OWNER_ID, cell)
	return id


func _add_resource_node(game_state: GameState, cell: Vector2i) -> int:
	var id: int = game_state.allocate_entity_id()
	game_state.entities[id] = {
		"id": id,
		"entity_type": "resource_node",
		"resource_type": "wood",
		"grid_position": cell,
		"remaining_amount": 80,
	}
	return id


func _add_worker_carrying(
	game_state: GameState,
	cell: Vector2i,
	stockpile_id: int,
	slot_cell: Vector2i,
	task_state: String
) -> int:
	var id: int = game_state.allocate_entity_id()
	game_state.entities[id] = {
		"id": id,
		"entity_type": "unit",
		"unit_role": "worker",
		"owner_id": OWNER_ID,
		"grid_position": cell,
		"move_target": cell,
		"path_cells": [],
		"has_move_target": false,
		"worker_task_state": task_state,
		"assigned_resource_node_id": 0,
		"assigned_stockpile_id": stockpile_id,
		"assigned_construction_site_id": 0,
		"carried_resource_type": "wood",
		"carried_amount": 5,
		"interaction_slot_cell": slot_cell,
		"traffic_state": "",
		"carry_capacity": 10,
		"harvest_amount": 5,
		"gather_duration_ticks": 8,
		"deposit_duration_ticks": 1,
		"gather_progress_ticks": 0,
	}
	game_state.occupancy[game_state.cell_key(cell)] = id
	return id


func _add_worker_to_resource(
	game_state: GameState,
	cell: Vector2i,
	resource_id: int,
	stockpile_id: int,
	slot_cell: Vector2i
) -> int:
	var id: int = game_state.allocate_entity_id()
	game_state.entities[id] = {
		"id": id,
		"entity_type": "unit",
		"unit_role": "worker",
		"owner_id": OWNER_ID,
		"grid_position": cell,
		"move_target": cell,
		"path_cells": [],
		"has_move_target": false,
		"worker_task_state": "to_resource",
		"assigned_resource_node_id": resource_id,
		"assigned_stockpile_id": stockpile_id,
		"assigned_construction_site_id": 0,
		"carried_resource_type": "",
		"carried_amount": 0,
		"interaction_slot_cell": slot_cell,
		"traffic_state": "",
		"carry_capacity": 10,
		"harvest_amount": 5,
		"gather_duration_ticks": 8,
		"deposit_duration_ticks": 1,
		"gather_progress_ticks": 0,
	}
	game_state.occupancy[game_state.cell_key(cell)] = id
	return id
