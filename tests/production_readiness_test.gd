extends SceneTree

## Headless tests: army pipeline readiness and producer batch ETA.

const GameStateClass = preload("res://simulation/game_state.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const StrategicTimingClass = preload("res://simulation/strategic_timing.gd")

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: int = 64
const OWNER_ID: int = 1


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(run_pipeline_all_ready_test())
	failures.append_array(run_pipeline_assembling_test())
	failures.append_array(run_pipeline_deployed_test())
	failures.append_array(run_pipeline_mixed_test())
	failures.append_array(run_batch_eta_single_test())
	failures.append_array(run_batch_eta_multi_test())
	failures.append_array(run_generic_army_bottleneck_test())
	if failures.is_empty():
		print("PRODUCTION_READINESS_TEST: PASS")
	else:
		print("PRODUCTION_READINESS_TEST: FAIL")
		for f in failures:
			print("  FAIL: %s" % f)
	quit()


## Test 1: 3 idle soldiers → all ready, 0 assembling, 0 deployed.
func run_pipeline_all_ready_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	_add_soldier(game_state, Vector2i(5, 5), "idle")
	_add_soldier(game_state, Vector2i(6, 5), "idle")
	_add_soldier(game_state, Vector2i(7, 5), "idle")

	var pipeline: Dictionary = StrategicTimingClass._get_army_pipeline(game_state, OWNER_ID)
	if int(pipeline.get("ready", 0)) != 3:
		failures.append("[all_ready] Expected ready=3, got %d" % int(pipeline.get("ready", 0)))
	if int(pipeline.get("assembling", 0)) != 0:
		failures.append("[all_ready] Expected assembling=0, got %d" % int(pipeline.get("assembling", 0)))
	if int(pipeline.get("deployed", 0)) != 0:
		failures.append("[all_ready] Expected deployed=0, got %d" % int(pipeline.get("deployed", 0)))
	print("[all_ready] pipeline: %s" % str(pipeline))
	return failures


## Test 2: 2 soldiers in to_rally → all assembling.
func run_pipeline_assembling_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	_add_soldier(game_state, Vector2i(5, 5), "to_rally")
	_add_soldier(game_state, Vector2i(6, 5), "to_rally")

	var pipeline: Dictionary = StrategicTimingClass._get_army_pipeline(game_state, OWNER_ID)
	if int(pipeline.get("assembling", 0)) != 2:
		failures.append("[assembling] Expected assembling=2, got %d" % int(pipeline.get("assembling", 0)))
	if int(pipeline.get("ready", 0)) != 0:
		failures.append("[assembling] Expected ready=0, got %d" % int(pipeline.get("ready", 0)))
	print("[assembling] pipeline: %s" % str(pipeline))
	return failures


## Test 3: 1 soldier attacking → deployed.
func run_pipeline_deployed_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	_add_soldier(game_state, Vector2i(5, 5), "attacking")

	var pipeline: Dictionary = StrategicTimingClass._get_army_pipeline(game_state, OWNER_ID)
	if int(pipeline.get("deployed", 0)) != 1:
		failures.append("[deployed] Expected deployed=1, got %d" % int(pipeline.get("deployed", 0)))
	if int(pipeline.get("ready", 0)) != 0:
		failures.append("[deployed] Expected ready=0, got %d" % int(pipeline.get("ready", 0)))

	# to_target also counts as deployed
	_add_soldier(game_state, Vector2i(6, 5), "to_target")
	pipeline = StrategicTimingClass._get_army_pipeline(game_state, OWNER_ID)
	if int(pipeline.get("deployed", 0)) != 2:
		failures.append("[deployed] Expected deployed=2 (attacking + to_target), got %d" % int(pipeline.get("deployed", 0)))
	print("[deployed] pipeline: %s" % str(pipeline))
	return failures


## Test 4: mixed pipeline — 1 ready, 1 assembling, 1 deployed, workers excluded.
func run_pipeline_mixed_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	_add_soldier(game_state, Vector2i(5, 5), "idle")
	_add_soldier(game_state, Vector2i(6, 5), "to_rally")
	_add_soldier(game_state, Vector2i(7, 5), "attacking")
	# Workers should not count as combat units in the pipeline
	_add_worker(game_state, Vector2i(8, 5), "idle")
	_add_worker(game_state, Vector2i(9, 5), "to_resource")

	var pipeline: Dictionary = StrategicTimingClass._get_army_pipeline(game_state, OWNER_ID)
	if int(pipeline.get("ready", 0)) != 1:
		failures.append("[mixed] Expected ready=1, got %d" % int(pipeline.get("ready", 0)))
	if int(pipeline.get("assembling", 0)) != 1:
		failures.append("[mixed] Expected assembling=1, got %d" % int(pipeline.get("assembling", 0)))
	if int(pipeline.get("deployed", 0)) != 1:
		failures.append("[mixed] Expected deployed=1, got %d" % int(pipeline.get("deployed", 0)))
	var total: int = int(pipeline.get("ready", 0)) + int(pipeline.get("assembling", 0)) + int(pipeline.get("deployed", 0))
	if total != 3:
		failures.append("[mixed] Expected total pipeline=3 (workers excluded), got %d" % total)
	print("[mixed] pipeline: %s" % str(pipeline))
	return failures


## Test 5: single unit in queue, partially progressed → batch ETA is remainder.
## Soldier duration = 15. At progress=5 → ETA = 15-5 = 10.
func run_batch_eta_single_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var producer_entity: Dictionary = _make_producer_entity(game_state, "barracks", 1, 15, 5)

	var eta: int = StrategicTimingClass.get_producer_batch_eta(game_state, producer_entity)
	if eta != 10:
		failures.append("[batch_single] Expected ETA=10 (15-5), got %d" % eta)
	print("[batch_single] batch ETA (1 queued, 5/15 progress): %d" % eta)
	return failures


## Test 6: 3 units queued, 5/15 progress → ETA = (15-5) + 2×15 = 40.
func run_batch_eta_multi_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()
	var producer_entity: Dictionary = _make_producer_entity(game_state, "barracks", 3, 15, 5)

	var eta: int = StrategicTimingClass.get_producer_batch_eta(game_state, producer_entity)
	if eta != 40:
		failures.append("[batch_multi] Expected ETA=40 (10 + 2×15), got %d" % eta)
	print("[batch_multi] batch ETA (3 queued, 5/15 progress): %d" % eta)
	return failures


## Test 7: _get_available_combat_unit_type returns non-empty for archery_range owner.
## Verifies the fix for the hardcoded "soldier" bottleneck bug.
func run_generic_army_bottleneck_test() -> Array[String]:
	var failures: Array[String] = []
	var game_state: GameState = _make_bare_game_state()

	# Add only an archery_range (no barracks)
	var range_id: int = game_state.allocate_entity_id()
	game_state.entities[range_id] = GameDefinitionsClass.create_structure_entity(
		"archery_range", range_id, OWNER_ID, Vector2i(10, 5), true
	)

	var unit_type: String = StrategicTimingClass._get_available_combat_unit_type(game_state, OWNER_ID)
	if unit_type == "":
		failures.append("[generic_bottleneck] Expected non-empty unit type for archery_range owner, got empty")
	if unit_type != "archer":
		failures.append("[generic_bottleneck] Expected unit_type=archer, got '%s'" % unit_type)
	print("[generic_bottleneck] available combat unit type: '%s'" % unit_type)
	return failures


## ── helpers ──────────────────────────────────────────────────────────────────


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


func _add_soldier(game_state: GameState, cell: Vector2i, task_state: String) -> void:
	var unit_id: int = game_state.allocate_entity_id()
	var entity: Dictionary = GameDefinitionsClass.create_unit_entity("soldier", unit_id, OWNER_ID, cell, 0)
	entity["worker_task_state"] = task_state
	game_state.entities[unit_id] = entity
	game_state.occupancy[game_state.cell_key(cell)] = unit_id


func _add_worker(game_state: GameState, cell: Vector2i, task_state: String) -> void:
	var unit_id: int = game_state.allocate_entity_id()
	var entity: Dictionary = GameDefinitionsClass.create_unit_entity("worker", unit_id, OWNER_ID, cell, 0)
	entity["worker_task_state"] = task_state
	game_state.entities[unit_id] = entity
	game_state.occupancy[game_state.cell_key(cell)] = unit_id


## Returns a minimal producer entity dict for batch ETA tests.
func _make_producer_entity(
	game_state: GameState,
	structure_type: String,
	queue_count: int,
	duration: int,
	progress: int
) -> Dictionary:
	var producer_id: int = game_state.allocate_entity_id()
	var entity: Dictionary = {
		"id": producer_id,
		"entity_type": "structure",
		"structure_type": structure_type,
		"is_constructed": true,
		"production_queue_count": queue_count,
		"produced_unit_type": "soldier",
		"production_duration_ticks": duration,
		"production_progress_ticks": progress,
	}
	game_state.entities[producer_id] = entity
	return game_state.get_entity_dict(producer_id)
