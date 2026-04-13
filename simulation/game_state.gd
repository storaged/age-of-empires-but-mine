class_name GameState
extends RefCounted

## Authoritative simulation data only.
## No camera, selection, hover, node refs, or presentation state here.

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")

var current_tick: int = 0
var next_entity_id: int = 1
var deterministic_seed: int = 1337
var deterministic_rng_state: int = 1337
var win_condition_met: bool = false
var lose_condition_met: bool = false

var entities: Dictionary = {}
var map_data: Dictionary = {}
var occupancy: Dictionary = {}
var resources: Dictionary = {}
var production_queues: Dictionary = {}
## Cache of cells blocked by structures, stockpiles, and resource nodes.
## Eliminates O(entity_count) scan in has_static_blocker_at_cell() during BFS.
var static_blocker_cells: Dictionary = {}

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
			return GameDefinitionsClass.normalize_entity(entity_value)
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


func is_game_over() -> bool:
	return win_condition_met or lose_condition_met


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

	# Greedy nearest-first deconfliction: process workers in sorted id order;
	# each claims the unclaimed slot nearest to their current position.
	# Deterministic: id order + nearest-first with (y,x) coord tie-break.
	var claimed: Array[Vector2i] = []
	for wid in worker_ids:
		var wpos: Vector2i = _raw_entity_grid_position(wid)
		var best: Vector2i = _nearest_unclaimed_slot(interaction_slots, claimed, wpos)
		if wid == worker_id:
			return best if best != Vector2i(-1, -1) else interaction_slots[0]
		if best != Vector2i(-1, -1):
			claimed.append(best)

	# Fallback: more workers than slots — wrap around unclaimed then claimed.
	var wpos: Vector2i = _raw_entity_grid_position(worker_id)
	return _nearest_unclaimed_slot(interaction_slots, [], wpos)


## Returns the raw grid_position from an entity dict without normalize overhead.
func _raw_entity_grid_position(entity_id: int) -> Vector2i:
	if not entities.has(entity_id):
		return Vector2i(-1, -1)
	var raw: Variant = entities[entity_id]
	if not (raw is Dictionary):
		return Vector2i(-1, -1)
	var pos: Variant = (raw as Dictionary).get("grid_position", Vector2i(-1, -1))
	if pos is Vector2i:
		return pos
	return Vector2i(-1, -1)


## Returns the unclaimed slot nearest to pos; Vector2i(-1,-1) if all slots claimed.
## Tie-break: lower y first, then lower x — deterministic.
func _nearest_unclaimed_slot(
	slots: Array[Vector2i],
	claimed: Array[Vector2i],
	pos: Vector2i
) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 999999
	for slot in slots:
		if claimed.has(slot):
			continue
		var dist: int = absi(slot.x - pos.x) + absi(slot.y - pos.y)
		if pos == Vector2i(-1, -1):
			dist = 0  # unknown position — treat all as equidistant, pick by coord
		if dist < best_dist or (dist == best_dist and _slot_before(slot, best)):
			best = slot
			best_dist = dist
	return best


func _slot_before(a: Vector2i, b: Vector2i) -> bool:
	if b == Vector2i(-1, -1):
		return true
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


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


func get_entity_vector2i(entity: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	if entity.has(key):
		var vector_value: Variant = entity[key]
		if vector_value is Vector2i:
			return vector_value
	return fallback


func get_entity_grid_position(entity: Dictionary, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	return get_entity_vector2i(entity, "grid_position", fallback)


func get_entity_move_target(entity: Dictionary, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	return get_entity_vector2i(entity, "move_target", fallback)


func get_entity_interaction_slot_cell(
	entity: Dictionary,
	fallback: Vector2i = Vector2i(-1, -1)
) -> Vector2i:
	return get_entity_vector2i(entity, "interaction_slot_cell", fallback)


func get_entity_structure_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "structure_type", "")


func get_entity_produced_unit_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "produced_unit_type", "")


func get_entity_rally_mode(entity: Dictionary) -> String:
	return get_entity_string(entity, "rally_mode", "")


func get_entity_rally_cell(entity: Dictionary) -> Vector2i:
	return get_entity_vector2i(entity, "rally_cell", Vector2i(-1, -1))


func get_entity_rally_target_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "rally_target_id", 0)


func get_entity_resource_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "resource_type", "")


func get_entity_supply_provided(entity: Dictionary) -> int:
	return get_entity_int(entity, "supply_provided", 0)


func get_entity_resource_trickle_type(entity: Dictionary) -> String:
	return get_entity_string(entity, "resource_trickle_type", "")


func get_entity_resource_trickle_amount(entity: Dictionary) -> int:
	return get_entity_int(entity, "resource_trickle_amount", 0)


func get_entity_resource_trickle_interval_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "resource_trickle_interval_ticks", 0)


func get_entity_resource_trickle_progress_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "resource_trickle_progress_ticks", 0)


func get_entity_population_cost(entity: Dictionary) -> int:
	return get_entity_int(entity, "population_cost", 0)


func get_entity_is_constructed(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "is_constructed", false)


func get_entity_is_production_blocked(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "production_blocked", false)


func get_entity_is_gatherable(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "is_gatherable", false)


func get_entity_is_depleted(entity: Dictionary) -> bool:
	return get_entity_bool(entity, "is_depleted", false)


func get_entity_owner_ids_units(owner_id: int) -> Array[int]:
	var unit_ids: Array[int] = []
	for entity_id in get_entities_by_type("unit"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_owner_id(entity) == owner_id:
			unit_ids.append(entity_id)
	return unit_ids


func get_entity_production_queue_count(entity: Dictionary) -> int:
	return get_entity_int(entity, "production_queue_count", 0)


func get_entity_movement_wait_ticks(entity: Dictionary) -> int:
	return get_entity_int(entity, "movement_wait_ticks", 0)


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
	return static_blocker_cells.has(cell_key(cell))


## Mark a cell as permanently blocked by a static entity (structure/stockpile/resource_node).
## Call when placing these entities so BFS pathfinding stays O(1) per cell.
func mark_static_blocker(cell: Vector2i) -> void:
	static_blocker_cells[cell_key(cell)] = true


## Rebuild the static blocker cache from scratch. Call once at game init.
## Reads entity dicts directly (no normalize_entity) — fast O(entity_count).
func rebuild_static_blocker_cache() -> void:
	static_blocker_cells = {}
	for entity_id in entities.keys():
		var entity_value: Variant = entities[entity_id]
		if not (entity_value is Dictionary):
			continue
		var entity: Dictionary = entity_value
		var entity_type_value: Variant = entity.get("entity_type", "")
		if not (entity_type_value is String):
			continue
		var entity_type: String = entity_type_value
		if entity_type != "resource_node" and entity_type != "stockpile" and entity_type != "structure":
			continue
		var pos_value: Variant = entity.get("grid_position", null)
		if not (pos_value is Vector2i):
			continue
		static_blocker_cells[cell_key(pos_value)] = true


func get_active_builder_id_for_structure(structure_id: int) -> int:
	for entity_id in get_entities_by_type("unit"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_unit_role(entity) != "worker":
			continue
		if get_entity_int(entity, "assigned_construction_site_id", 0) != structure_id:
			continue
		var task: String = get_entity_task_state(entity)
		if task == "to_construction" or task == "constructing":
			return entity_id
	return 0


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


func get_entity_hp(entity: Dictionary) -> int:
	return get_entity_int(entity, "hp", 0)


func get_entity_max_hp(entity: Dictionary) -> int:
	return get_entity_int(entity, "max_hp", 0)


func get_entity_attack_target_id(entity: Dictionary) -> int:
	return get_entity_int(entity, "attack_target_id", 0)


func get_entity_attack_cooldown_remaining(entity: Dictionary) -> int:
	return get_entity_int(entity, "attack_cooldown_remaining", 0)


func get_entity_attack_range_cells(entity: Dictionary) -> int:
	return get_entity_int(entity, "attack_range_cells", 0)


func get_entity_vision_radius(entity: Dictionary) -> int:
	return get_entity_int(entity, "vision_radius_cells", 0)


func get_structure_cost(structure_type: String) -> int:
	return GameDefinitionsClass.get_building_cost(structure_type)


func get_structure_construction_duration(structure_type: String) -> int:
	return GameDefinitionsClass.get_building_construction_duration(structure_type)


func get_production_cost(unit_type: String) -> int:
	return GameDefinitionsClass.get_unit_production_cost(unit_type)


func get_production_duration(unit_type: String) -> int:
	return GameDefinitionsClass.get_unit_production_duration(unit_type)


## Returns true if the player has enough of every resource required to place this building.
func can_afford_building(structure_type: String) -> bool:
	var costs: Dictionary = GameDefinitionsClass.get_building_costs(structure_type)
	for resource_type in costs.keys():
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		if get_resource_amount(resource_type) < cost:
			return false
	return true


func get_missing_costs(costs: Dictionary) -> Dictionary:
	var missing_costs: Dictionary = {}
	var resource_types: Array = costs.keys()
	resource_types.sort()
	for resource_type_variant in resource_types:
		if not (resource_type_variant is String):
			continue
		var resource_type: String = resource_type_variant
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		var available: int = get_resource_amount(resource_type)
		if available < cost:
			missing_costs[resource_type] = cost - available
	return missing_costs


func get_missing_building_costs(structure_type: String) -> Dictionary:
	return get_missing_costs(GameDefinitionsClass.get_building_costs(structure_type))


func get_missing_production_costs(unit_type: String) -> Dictionary:
	return get_missing_costs(GameDefinitionsClass.get_unit_production_costs(unit_type))


## Deducts all resource costs for placing a building. Call only after can_afford_building() is true.
func deduct_building_cost(structure_type: String) -> void:
	var costs: Dictionary = GameDefinitionsClass.get_building_costs(structure_type)
	for resource_type in costs.keys():
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		if cost > 0:
			resources[resource_type] = get_resource_amount(resource_type) - cost


## Refunds all resource costs for a building (used when placement validation fails post-deduction).
func refund_building_cost(structure_type: String) -> void:
	var costs: Dictionary = GameDefinitionsClass.get_building_costs(structure_type)
	for resource_type in costs.keys():
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		if cost > 0:
			resources[resource_type] = get_resource_amount(resource_type) + cost


## Returns true if the prerequisite building for this structure type is already completed.
func is_prerequisite_met(structure_type: String) -> bool:
	var required_type: String = GameDefinitionsClass.get_building_prerequisite(structure_type)
	if required_type == "":
		return true
	for entity_id in get_entities_by_type("structure"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_structure_type(entity) == required_type and get_entity_is_constructed(entity):
			return true
	return false


## Returns true if the player can afford all production costs for this unit type.
func can_afford_production(unit_type: String) -> bool:
	var costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(unit_type)
	for resource_type in costs.keys():
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		if get_resource_amount(resource_type) < cost:
			return false
	return true


func get_population_used(owner_id: int) -> int:
	var population_used: int = 0
	for entity_id in get_entities_by_type("unit"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_owner_id(entity) != owner_id:
			continue
		population_used += get_entity_population_cost(entity)
	return population_used


func get_population_reserved(owner_id: int) -> int:
	var population_reserved: int = get_population_used(owner_id)
	var producer_ids: Array[int] = []
	for entity_id in get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in get_entities_by_type("structure"):
		producer_ids.append(entity_id)
	producer_ids.sort()

	for producer_id in producer_ids:
		var producer_entity: Dictionary = get_entity_dict(producer_id)
		if get_entity_owner_id(producer_entity) != owner_id:
			continue
		var queue_count: int = get_entity_production_queue_count(producer_entity)
		if queue_count <= 0:
			continue
		var unit_type: String = get_entity_produced_unit_type(producer_entity)
		if unit_type == "":
			continue
		population_reserved += queue_count * GameDefinitionsClass.get_unit_population_cost(unit_type)
	return population_reserved


func get_population_queued(owner_id: int) -> int:
	return maxi(get_population_reserved(owner_id) - get_population_used(owner_id), 0)


func get_population_cap(owner_id: int) -> int:
	var population_cap: int = GameDefinitionsClass.get_base_population_cap()
	for entity_id in get_entities_by_type("structure"):
		var entity: Dictionary = get_entity_dict(entity_id)
		if get_entity_owner_id(entity) != owner_id:
			continue
		if not get_entity_is_constructed(entity):
			continue
		population_cap += get_entity_supply_provided(entity)
	return population_cap


func can_queue_population_for_unit(owner_id: int, unit_type: String) -> bool:
	var population_cost: int = GameDefinitionsClass.get_unit_population_cost(unit_type)
	if population_cost <= 0:
		return true
	return get_population_reserved(owner_id) + population_cost <= get_population_cap(owner_id)


func is_population_capped_for_unit(owner_id: int, unit_type: String) -> bool:
	return not can_queue_population_for_unit(owner_id, unit_type)


## Deducts all resource costs for producing a unit. Call only after can_afford_production() is true.
func deduct_production_cost(unit_type: String) -> void:
	var costs: Dictionary = GameDefinitionsClass.get_unit_production_costs(unit_type)
	for resource_type in costs.keys():
		var cost_value: Variant = costs[resource_type]
		var cost: int = cost_value if cost_value is int else 0
		if cost > 0:
			resources[resource_type] = get_resource_amount(resource_type) - cost


## Returns true if this entity has the fields needed to participate in combat as an attacker.
func get_entity_can_attack(entity: Dictionary) -> bool:
	return get_entity_int(entity, "attack_damage", 0) > 0


func get_entity_is_ranged_attacker(entity: Dictionary) -> bool:
	return get_entity_attack_range_cells(entity) > 1 and get_entity_can_attack(entity)


func get_entity_is_damageable(entity: Dictionary) -> bool:
	return get_entity_max_hp(entity) > 0


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
		"win_condition_met": win_condition_met,
		"lose_condition_met": lose_condition_met,
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
