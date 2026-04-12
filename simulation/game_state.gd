class_name GameState
extends RefCounted

## Authoritative simulation data only.
## No camera, selection, hover, node refs, or presentation state here.

var current_tick: int = 0
var next_entity_id: int = 1
var deterministic_seed: int = 1337
var deterministic_rng_state: int = 1337

var entities: Dictionary = {}
var map_data: Dictionary = {}
var occupancy: Dictionary = {}
var resources: Dictionary = {}
var production_queues: Dictionary = {}

# Phase 1 smoke-test state. Still authoritative data.
var debug_counter: int = 0
var executed_command_ids: Array[String] = []


func allocate_entity_id() -> int:
	var entity_id: int = next_entity_id
	next_entity_id += 1
	return entity_id


func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func get_map_width() -> int:
	if map_data.has("width"):
		var width_value: Variant = map_data["width"]
		if width_value is int:
			return width_value
	return 0


func get_map_height() -> int:
	if map_data.has("height"):
		var height_value: Variant = map_data["height"]
		if height_value is int:
			return height_value
	return 0


func get_blocked_cells() -> Dictionary:
	if map_data.has("blocked_cells"):
		var blocked_cells_value: Variant = map_data["blocked_cells"]
		if blocked_cells_value is Dictionary:
			return blocked_cells_value
	return {}


func get_entity_dict(entity_id: int) -> Dictionary:
	if entities.has(entity_id):
		var entity_value: Variant = entities[entity_id]
		if entity_value is Dictionary:
			return entity_value
	return {}


func get_entity_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "entity_type", "")


func get_entity_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "id", 0)


func get_entity_string(entity: Dictionary, key: String, fallback: String = "") -> String:
	if entity.has(key):
		var entity_string_value: Variant = entity[key]
		if entity_string_value is String:
			return entity_string_value
	return fallback


func get_entity_int(entity: Dictionary, key: String, fallback: int = 0) -> int:
	if entity.has(key):
		var entity_int_value: Variant = entity[key]
		if entity_int_value is int:
			return entity_int_value
	return fallback


func get_entity_bool(entity: Dictionary, key: String, fallback: bool = false) -> bool:
	if entity.has(key):
		var entity_bool_value: Variant = entity[key]
		if entity_bool_value is bool:
			return entity_bool_value
	return fallback


func get_resource_amount(resource_type: String) -> int:
	if resources.has(resource_type):
		var resource_amount_value: Variant = resources[resource_type]
		if resource_amount_value is int:
			return resource_amount_value
	return 0


func get_entities_by_type(entity_type: String) -> Array[int]:
	var entity_ids: Array[int] = []
	var keys: Array = entities.keys()
	keys.sort()
	for entity_id in keys:
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_type(entity) == entity_type:
			entity_ids.append(entity_id)
	return entity_ids


func get_adjacent_walkable_cells(target_cell: Vector2i) -> Array[Vector2i]:
	var adjacent_cells: Array[Vector2i] = []
	var candidate_offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for offset in candidate_offsets:
		var candidate_cell: Vector2i = target_cell + offset
		if is_cell_walkable(candidate_cell):
			adjacent_cells.append(candidate_cell)
	return adjacent_cells


func get_worker_ids_for_assignment(
	target_field: String,
	target_id: int,
	allowed_task_states: Array[String]
) -> Array[int]:
	var worker_ids: Array[int] = []
	for entity_id in get_entities_by_type("unit"):
		var worker_entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_unit_role(worker_entity) != "worker":
			continue
		if get_entity_int(worker_entity, target_field, 0) != target_id:
			continue
		if not allowed_task_states.has(get_entity_task_state(worker_entity)):
			continue
		worker_ids.append(entity_id)
	return worker_ids


func get_interaction_slot_for_worker(
	target_cell: Vector2i,
	target_field: String,
	target_id: int,
	worker_id: int,
	allowed_task_states: Array[String]
) -> Vector2i:
	var interaction_slots: Array[Vector2i] = get_adjacent_walkable_cells(target_cell)
	if interaction_slots.is_empty():
		return Vector2i(-1, -1)

	var worker_ids: Array[int] = get_worker_ids_for_assignment(
		target_field,
		target_id,
		allowed_task_states
	)
	if not worker_ids.has(worker_id):
		worker_ids.append(worker_id)
		worker_ids.sort()
	var worker_index: int = worker_ids.find(worker_id)
	if worker_index == -1:
		worker_index = 0

	return interaction_slots[worker_index % interaction_slots.size()]


func are_cells_adjacent(left: Vector2i, right: Vector2i) -> bool:
	return absi(left.x - right.x) + absi(left.y - right.y) == 1


func get_entity_owner_id(entity: Dictionary, fallback: int = 0) -> int:
	return get_entity_int(entity, "owner_id", fallback)


func get_entity_unit_role(entity: Dictionary) -> String:
	return get_entity_string(entity, "unit_role", "")


func get_entity_task_state(entity: Dictionary) -> String:
	return get_entity_string(entity, "worker_task_state", "idle")


func get_entity_assigned_resource_node_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "assigned_resource_node_id", 0)


func get_entity_assigned_stockpile_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "assigned_stockpile_id", 0)


func get_entity_assigned_construction_site_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "assigned_construction_site_id", 0)


func get_entity_carried_resource_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "carried_resource_type", "")


func get_entity_carried_amount(entity: Dictionary) -> int:
	return get_entity_int(entity, "carried_amount", 0)


func get_entity_gather_progress(entity: Dictionary) -> int:
	return get_entity_int(entity, "gather_progress_ticks", 0)


func get_entity_remaining_amount(entity: Dictionary) -> int:
	return get_entity_int(entity, "remaining_amount", 0)


func get_entity_capacity(entity: Dictionary) -> int:
	return get_entity_int(entity, "carry_capacity", 0)


func get_entity_harvest_amount(entity: Dictionary) -> int:
	return get_entity_int(entity, "harvest_amount", 0)


func get_entity_gather_duration_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "gather_duration_ticks", 0)


func get_entity_deposit_duration_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "deposit_duration_ticks", 0)


func get_entity_construction_duration_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "construction_duration_ticks", 0)


func get_entity_construction_progress_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "construction_progress_ticks", 0)


func get_entity_production_progress_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "production_progress_ticks", 0)


func get_entity_production_duration_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "production_duration_ticks", 0)


func get_entity_grid_position(entity: Dictionary, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if entity.has("grid_position"):
		var grid_position_value: Variant = entity["grid_position"]
		if grid_position_value is Vector2i:
			return grid_position_value
	return fallback


func get_entity_move_target(entity: Dictionary, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if entity.has("move_target"):
		var move_target_value: Variant = entity["move_target"]
		if move_target_value is Vector2i:
			return move_target_value
	return fallback


func get_entity_interaction_slot_cell(
	entity: Dictionary,
	fallback: Vector2i = Vector2i(-1, -1)
) -> Vector2i:
	if entity.has("interaction_slot_cell"):
		var interaction_slot_value: Variant = entity["interaction_slot_cell"]
		if interaction_slot_value is Vector2i:
			return interaction_slot_value
	return fallback


func get_entity_structure_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "structure_type", "")


func get_entity_produced_unit_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "produced_unit_type", "")


func get_entity_resource_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "resource_type", "")


func get_entity_is_constructed(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "is_constructed", false)


func get_entity_is_production_blocked(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "production_blocked", false)


func get_entity_owner_ids_units(owner_id: int) -> Array[int]:
	var unit_ids: Array[int] = []
	for entity_id in get_entities_by_type("unit"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_owner_id(entity) == owner_id:
			unit_ids.append(entity_id)
	return unit_ids


func get_entity_production_queue_count(entity: Dictionary) -> int:
	return get_entity_int(entity, "production_queue_count", 0)


func get_entity_has_move_target(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "has_move_target", false)


func get_entity_path_cells(entity: Dictionary) -> Array[Vector2i]:
	var path_cells: Array[Vector2i] = []
	if not entity.has("path_cells"):
		return path_cells

	var path_cells_value: Variant = entity["path_cells"]
	if not (path_cells_value is Array):
		return path_cells

	for path_cell_value in path_cells_value:
		if path_cell_value is Vector2i:
			path_cells.append(path_cell_value)
	return path_cells


func is_cell_blocked(cell: Vector2i) -> bool:
	var blocked_cells: Dictionary = get_blocked_cells()
	if blocked_cells.has(cell_key(cell)):
		return true
	return has_static_blocker_at_cell(cell)


func is_cell_walkable(cell: Vector2i) -> bool:
	var width: int = get_map_width()
	var height: int = get_map_height()
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false

	return not is_cell_blocked(cell)


func is_cell_occupied_by_unit(cell: Vector2i) -> bool:
	return occupancy.has(cell_key(cell))


func has_static_blocker_at_cell(cell: Vector2i) -> bool:
	for entity_id in entities.keys():
		var entity: Dictionary = get_entity_dict(entity_id)
		var entity_type: String = get_entity_type(entity)
		if entity_type != "resource_node" and entity_type != "stockpile" and entity_type != "structure":
			continue
		if get_entity_grid_position(entity, Vector2i(-999, -999)) != cell:
			continue
		return true
	return false


func get_selectable_entity_id_at_cell(cell: Vector2i) -> int:
	for entity_id in get_entities_by_type("stockpile"):
		var stockpile_entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_grid_position(stockpile_entity, Vector2i(-1, -1)) == cell:
			return entity_id
	for entity_id in get_entities_by_type("structure"):
		var structure_entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_grid_position(structure_entity, Vector2i(-1, -1)) == cell:
			return entity_id
	return 0


func can_place_structure_at(cell: Vector2i) -> bool:
	if not is_cell_walkable(cell):
		return false
	if is_cell_occupied_by_unit(cell):
		return false
	if has_static_blocker_at_cell(cell):
		return false
	return true


func get_structure_cost(structure_type: String) -> int:
	if structure_type == "house":
		return 30
	return 0


func get_structure_construction_duration(structure_type: String) -> int:
	if structure_type == "house":
		return 24
	return 0


func get_production_cost(unit_type: String) -> int:
	if unit_type == "worker":
		return 20
	return 0


func get_production_duration(unit_type: String) -> int:
	if unit_type == "worker":
		return 18
	return 0


func get_spawn_cells_around(cell: Vector2i) -> Array[Vector2i]:
	var spawn_cells: Array[Vector2i] = []
	var candidate_offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1),
	]
	for offset in candidate_offsets:
		var candidate_cell: Vector2i = cell + offset
		if candidate_cell.x < 0 or candidate_cell.y < 0:
			continue
		if candidate_cell.x >= get_map_width() or candidate_cell.y >= get_map_height():
			continue
		spawn_cells.append(candidate_cell)
	return spawn_cells


func to_authoritative_dict() -> Dictionary:
	return {
		"current_tick": current_tick,
		"next_entity_id": next_entity_id,
		"deterministic_seed": deterministic_seed,
		"deterministic_rng_state": deterministic_rng_state,
		"entities": _canonicalize_variant(entities),
		"map_data": _canonicalize_variant(map_data),
		"occupancy": _canonicalize_variant(occupancy),
		"resources": _canonicalize_variant(resources),
		"production_queues": _canonicalize_variant(production_queues),
		"debug_counter": debug_counter,
		"executed_command_ids": _canonicalize_variant(executed_command_ids),
	}


func serialize_canonical() -> String:
	return JSON.stringify(to_authoritative_dict())


func _canonicalize_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var items: Array[Dictionary] = []
		for key in keys:
			items.append({
				"key": str(key),
				"value": _canonicalize_variant(value[key]),
			})
		return items

	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_canonicalize_variant(item))
		return items

	if value is Vector2i:
		return [value.x, value.y]

	if value is Vector2:
		return [value.x, value.y]

	return value
