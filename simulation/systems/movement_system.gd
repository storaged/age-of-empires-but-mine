class_name MovementSystem
extends SimulationSystem

const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")

## Deterministic grid-backed unit movement with simple local traffic resolution.
## Resolution order:
## 1. Build one-cell move intents in stable priority order.
## 2. Resolve direct two-unit swaps deterministically.
## 3. Run repeated movement passes so vacated cells can be entered in the same tick.
## 4. After bounded waiting, recompute a path to the same authoritative target.

const TRAFFIC_PRIORITY_BY_TASK: Dictionary = {
	"depositing": 0,
	"to_stockpile": 1,
	"gathering": 2,
	"to_resource": 3,
	"to_construction": 3,
	"to_target": 3,
	"attack_moving": 3,
	"to_rally": 4,
	"idle": 4,
}
const REPATH_AFTER_WAIT_TICKS: int = 3


func apply(game_state: GameState, _commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	var entity_ids: Array[int] = game_state.get_entities_by_type("unit")
	var reserved_cells: Dictionary = _copy_dictionary(game_state.occupancy)
	var start_occupancy: Dictionary = _copy_dictionary(game_state.occupancy)
	var intents_by_id: Dictionary = {}
	var ordered_intent_ids: Array[int] = []
	var moved_unit_ids: Dictionary = {}

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		entity["traffic_state"] = ""

		if not game_state.get_entity_has_move_target(entity):
			entity["movement_wait_ticks"] = 0
			game_state.entities[entity_id] = entity
			continue

		var path_cells: Array[Vector2i] = game_state.get_entity_path_cells(entity)
		var current_cell: Vector2i = game_state.get_entity_grid_position(entity)
		if path_cells.is_empty():
			entity["has_move_target"] = false
			entity["move_target"] = current_cell
			entity["traffic_state"] = "arrived"
			entity["movement_wait_ticks"] = 0
			game_state.entities[entity_id] = entity
			continue

		var next_cell: Vector2i = path_cells[0]
		intents_by_id[entity_id] = {
			"entity_id": entity_id,
			"current_cell": current_cell,
			"next_cell": next_cell,
			"priority": _movement_priority(game_state, entity),
		}
		ordered_intent_ids.append(entity_id)
		game_state.entities[entity_id] = entity

	ordered_intent_ids.sort_custom(Callable(self, "_sort_intents").bind(intents_by_id))
	_resolve_direct_swaps(game_state, intents_by_id, ordered_intent_ids, reserved_cells, start_occupancy, moved_unit_ids)

	var progress_made: bool = true
	while progress_made:
		progress_made = false
		for entity_id in ordered_intent_ids:
			if moved_unit_ids.has(entity_id):
				continue

			var intent: Dictionary = _get_intent_dict(intents_by_id, entity_id)
			if intent.is_empty():
				continue

			var next_cell: Vector2i = _get_intent_cell(intent, "next_cell")
			var current_cell: Vector2i = _get_intent_cell(intent, "current_cell")
			var current_key: String = game_state.cell_key(current_cell)
			var next_key: String = game_state.cell_key(next_cell)

			if game_state.is_cell_blocked(next_cell):
				var blocked_entity: Dictionary = game_state.get_entity_dict(entity_id)
				blocked_entity["traffic_state"] = "blocked"
				game_state.entities[entity_id] = blocked_entity
				continue

			if reserved_cells.has(next_key):
				var occupied_by_value: Variant = reserved_cells[next_key]
				if occupied_by_value is int and occupied_by_value != entity_id:
					continue
			reserved_cells.erase(current_key)
			reserved_cells[next_key] = entity_id
			_apply_step(game_state, entity_id, next_cell, "moving")
			moved_unit_ids[entity_id] = true
			progress_made = true

	for entity_id in ordered_intent_ids:
		if moved_unit_ids.has(entity_id):
			continue

		var intent: Dictionary = _get_intent_dict(intents_by_id, entity_id)
		if intent.is_empty():
			continue

		var wait_reason: String = _build_wait_reason(game_state, intent, start_occupancy)
		var waiting_entity: Dictionary = game_state.get_entity_dict(entity_id)
		waiting_entity["traffic_state"] = wait_reason
		_maybe_recompute_path(game_state, waiting_entity, wait_reason)
		game_state.entities[entity_id] = waiting_entity

	game_state.occupancy = reserved_cells


func _resolve_direct_swaps(
	game_state: GameState,
	intents_by_id: Dictionary,
	ordered_intent_ids: Array[int],
	reserved_cells: Dictionary,
	start_occupancy: Dictionary,
	moved_unit_ids: Dictionary
) -> void:
	for entity_id in ordered_intent_ids:
		if moved_unit_ids.has(entity_id):
			continue

		var intent: Dictionary = _get_intent_dict(intents_by_id, entity_id)
		if intent.is_empty():
			continue
		var next_cell: Vector2i = _get_intent_cell(intent, "next_cell")
		var current_cell: Vector2i = _get_intent_cell(intent, "current_cell")
		var next_key: String = game_state.cell_key(next_cell)
		if not start_occupancy.has(next_key):
			continue

		var other_unit_value: Variant = start_occupancy[next_key]
		if not (other_unit_value is int):
			continue
		var other_unit_id: int = other_unit_value
		if other_unit_id == entity_id:
			continue
		if moved_unit_ids.has(other_unit_id):
			continue
		if not intents_by_id.has(other_unit_id):
			continue

		var other_intent: Dictionary = _get_intent_dict(intents_by_id, other_unit_id)
		if other_intent.is_empty():
			continue
		var other_current_cell: Vector2i = _get_intent_cell(other_intent, "current_cell")
		var other_next_cell: Vector2i = _get_intent_cell(other_intent, "next_cell")
		if other_current_cell != next_cell or other_next_cell != current_cell:
			continue
		if not game_state.are_cells_adjacent(current_cell, next_cell):
			continue
		if game_state.is_cell_blocked(next_cell) or game_state.is_cell_blocked(other_next_cell):
			continue

		var current_key: String = game_state.cell_key(current_cell)
		var other_key: String = game_state.cell_key(other_current_cell)
		reserved_cells.erase(current_key)
		reserved_cells.erase(other_key)
		reserved_cells[game_state.cell_key(next_cell)] = entity_id
		reserved_cells[game_state.cell_key(other_next_cell)] = other_unit_id
		_apply_step(game_state, entity_id, next_cell, "swapping")
		_apply_step(game_state, other_unit_id, other_next_cell, "swapping")
		moved_unit_ids[entity_id] = true
		moved_unit_ids[other_unit_id] = true


func _apply_step(game_state: GameState, entity_id: int, next_cell: Vector2i, traffic_state: String) -> void:
	var entity: Dictionary = game_state.get_entity_dict(entity_id)
	var path_cells: Array[Vector2i] = game_state.get_entity_path_cells(entity)
	entity["grid_position"] = next_cell
	if not path_cells.is_empty():
		path_cells.remove_at(0)
	entity["path_cells"] = path_cells
	entity["has_move_target"] = not path_cells.is_empty()
	entity["traffic_state"] = traffic_state
	entity["movement_wait_ticks"] = 0
	if path_cells.is_empty():
		entity["move_target"] = next_cell
	game_state.entities[entity_id] = entity


func _maybe_recompute_path(
	game_state: GameState,
	entity: Dictionary,
	wait_reason: String
) -> void:
	if wait_reason != "waiting" and wait_reason != "yielding":
		entity["movement_wait_ticks"] = 0
		return
	if not game_state.get_entity_has_move_target(entity):
		entity["movement_wait_ticks"] = 0
		return

	var current_cell: Vector2i = game_state.get_entity_grid_position(entity)
	var target_cell: Vector2i = game_state.get_entity_move_target(entity, current_cell)
	if current_cell == target_cell:
		entity["movement_wait_ticks"] = 0
		return

	var wait_ticks: int = game_state.get_entity_movement_wait_ticks(entity) + 1
	entity["movement_wait_ticks"] = wait_ticks
	if wait_ticks < REPATH_AFTER_WAIT_TICKS:
		return

	var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state, current_cell, target_cell, true
	)
	if path_cells.is_empty():
		path_cells = DeterministicPathfinderClass.find_path(game_state, current_cell, target_cell, false)
	if path_cells.is_empty():
		return

	entity["path_cells"] = path_cells
	entity["has_move_target"] = true
	entity["movement_wait_ticks"] = 0
	entity["traffic_state"] = "repathing"


func _build_wait_reason(game_state: GameState, intent: Dictionary, start_occupancy: Dictionary) -> String:
	var next_cell: Vector2i = _get_intent_cell(intent, "next_cell")
	if game_state.is_cell_blocked(next_cell):
		return "blocked"

	var next_key: String = game_state.cell_key(next_cell)
	if start_occupancy.has(next_key):
		var blocker_value: Variant = start_occupancy[next_key]
		if blocker_value is int:
			var blocker_id: int = blocker_value
			var blocker_entity: Dictionary = game_state.get_entity_dict(blocker_id)
			if _movement_priority(game_state, blocker_entity) < _get_intent_priority(intent):
				return "yielding"
	return "waiting"


func _movement_priority(game_state: GameState, entity: Dictionary) -> int:
	var task_state: String = game_state.get_entity_task_state(entity)
	if TRAFFIC_PRIORITY_BY_TASK.has(task_state):
		var priority_value: Variant = TRAFFIC_PRIORITY_BY_TASK[task_state]
		if priority_value is int:
			return priority_value
	return 10


func _sort_intents(left_id: int, right_id: int, intents_by_id: Dictionary) -> bool:
	var left_intent: Dictionary = _get_intent_dict(intents_by_id, left_id)
	var right_intent: Dictionary = _get_intent_dict(intents_by_id, right_id)
	var left_priority: int = _get_intent_priority(left_intent)
	var right_priority: int = _get_intent_priority(right_intent)
	if left_priority != right_priority:
		return left_priority < right_priority
	return left_id < right_id


func _get_intent_dict(intents_by_id: Dictionary, entity_id: int) -> Dictionary:
	if not intents_by_id.has(entity_id):
		return {}
	var intent_value: Variant = intents_by_id[entity_id]
	if intent_value is Dictionary:
		return intent_value
	return {}


func _get_intent_cell(intent: Dictionary, key: String) -> Vector2i:
	if not intent.has(key):
		return Vector2i.ZERO
	var cell_value: Variant = intent[key]
	if cell_value is Vector2i:
		return cell_value
	return Vector2i.ZERO


func _get_intent_priority(intent: Dictionary) -> int:
	if not intent.has("priority"):
		return 10
	var priority_value: Variant = intent["priority"]
	if priority_value is int:
		return priority_value
	return 10


func _copy_dictionary(source: Dictionary) -> Dictionary:
	var copied: Dictionary = {}
	for key in source.keys():
		copied[key] = source[key]
	return copied
