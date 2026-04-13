class_name ProductionSystem
extends SimulationSystem

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")


func apply(game_state: GameState, _commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	var producer_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		producer_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if not game_state.get_entity_is_constructed(structure_entity):
			continue
		producer_ids.append(entity_id)
	producer_ids.sort()

	for producer_id in producer_ids:
		var producer_entity: Dictionary = game_state.get_entity_dict(producer_id)
		var queue_count: int = game_state.get_entity_production_queue_count(producer_entity)
		if queue_count <= 0:
			producer_entity["production_progress_ticks"] = 0
			producer_entity["production_blocked"] = false
			game_state.entities[producer_id] = producer_entity
			continue

		var produced_unit_type: String = game_state.get_entity_produced_unit_type(producer_entity)
		var production_duration: int = maxi(game_state.get_entity_production_duration_ticks(producer_entity), 1)
		var progress: int = mini(
			game_state.get_entity_production_progress_ticks(producer_entity) + 1,
			production_duration
		)
		producer_entity["production_progress_ticks"] = progress
		if progress < production_duration:
			game_state.entities[producer_id] = producer_entity
			continue

		var spawn_cell: Vector2i = _find_spawn_cell(game_state, producer_entity)
		if spawn_cell == Vector2i(-1, -1):
			producer_entity["production_blocked"] = true
			game_state.entities[producer_id] = producer_entity
			continue

		_spawn_unit(game_state, producer_entity, produced_unit_type, spawn_cell, producer_id)
		producer_entity["production_queue_count"] = queue_count - 1
		producer_entity["production_progress_ticks"] = 0
		producer_entity["production_blocked"] = false
		if producer_entity["production_queue_count"] <= 0:
			producer_entity["produced_unit_type"] = ""
		game_state.entities[producer_id] = producer_entity


func _find_spawn_cell(game_state: GameState, producer_entity: Dictionary) -> Vector2i:
	var producer_cell: Vector2i = game_state.get_entity_grid_position(producer_entity)
	var spawn_cells: Array[Vector2i] = game_state.get_spawn_cells_around(producer_cell)
	for spawn_cell in spawn_cells:
		if not game_state.is_cell_walkable(spawn_cell):
			continue
		if game_state.is_cell_occupied_by_unit(spawn_cell):
			continue
		return spawn_cell
	return Vector2i(-1, -1)


func _spawn_unit(
	game_state: GameState,
	producer_entity: Dictionary,
	produced_unit_type: String,
	spawn_cell: Vector2i,
	producer_id: int
) -> void:
	var owner_id: int = game_state.get_entity_owner_id(producer_entity, 1)
	var unit_id: int = game_state.allocate_entity_id()

	var entity: Dictionary = GameDefinitionsClass.create_unit_entity(
		produced_unit_type, unit_id, owner_id, spawn_cell, producer_id
	)
	if entity.is_empty():
		game_state.next_entity_id -= 1
		return

	_apply_rally_after_spawn(game_state, producer_entity, entity, unit_id)
	game_state.entities[unit_id] = entity
	game_state.occupancy[game_state.cell_key(spawn_cell)] = unit_id


func _apply_rally_after_spawn(
	game_state: GameState,
	producer_entity: Dictionary,
	spawned_entity: Dictionary,
	spawned_unit_id: int
) -> void:
	var rally_mode: String = game_state.get_entity_rally_mode(producer_entity)
	if rally_mode == "":
		return

	if rally_mode == "resource" and game_state.get_entity_unit_role(spawned_entity) == "worker":
		_apply_worker_resource_rally(game_state, producer_entity, spawned_entity, spawned_unit_id)
		return

	if rally_mode == "cell":
		_apply_move_rally(game_state, producer_entity, spawned_entity)


func _apply_move_rally(
	game_state: GameState,
	producer_entity: Dictionary,
	spawned_entity: Dictionary
) -> void:
	var from_cell: Vector2i = game_state.get_entity_grid_position(spawned_entity)
	var rally_cell: Vector2i = game_state.get_entity_rally_cell(producer_entity)
	if rally_cell.x < 0 or rally_cell.y < 0:
		return
	if not game_state.is_cell_walkable(rally_cell):
		return
	var path_cells: Array[Vector2i] = _find_path_avoid_occupied(game_state, from_cell, rally_cell)
	if from_cell != rally_cell and path_cells.is_empty():
		return
	spawned_entity["path_cells"] = path_cells
	spawned_entity["has_move_target"] = not path_cells.is_empty()
	spawned_entity["move_target"] = rally_cell
	spawned_entity["worker_task_state"] = "to_rally" if not path_cells.is_empty() else "idle"
	spawned_entity["interaction_slot_cell"] = rally_cell


func _apply_worker_resource_rally(
	game_state: GameState,
	producer_entity: Dictionary,
	spawned_entity: Dictionary,
	spawned_unit_id: int
) -> void:
	var resource_node_id: int = game_state.get_entity_rally_target_id(producer_entity)
	if resource_node_id == 0 or not game_state.entities.has(resource_node_id):
		return
	var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
	if game_state.get_entity_type(resource_entity) != "resource_node":
		return
	if game_state.get_entity_is_depleted(resource_entity):
		return

	var stockpile_id: int = _find_best_stockpile_id(game_state, spawned_entity)
	if stockpile_id == 0:
		return

	var resource_cell: Vector2i = game_state.get_entity_grid_position(resource_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		resource_cell,
		"assigned_resource_node_id",
		resource_node_id,
		spawned_unit_id,
		["to_resource", "gathering"]
	)
	if slot_cell == Vector2i(-1, -1):
		return

	var spawn_cell: Vector2i = game_state.get_entity_grid_position(spawned_entity)
	var path_cells: Array[Vector2i] = _find_path_avoid_occupied(game_state, spawn_cell, slot_cell)
	if spawn_cell != slot_cell and path_cells.is_empty():
		return

	spawned_entity["assigned_resource_node_id"] = resource_node_id
	spawned_entity["assigned_stockpile_id"] = stockpile_id
	spawned_entity["assigned_construction_site_id"] = 0
	spawned_entity["gather_progress_ticks"] = 0
	spawned_entity["path_cells"] = path_cells
	spawned_entity["has_move_target"] = not path_cells.is_empty()
	spawned_entity["move_target"] = slot_cell
	spawned_entity["worker_task_state"] = "to_resource"
	spawned_entity["interaction_slot_cell"] = slot_cell


func _find_best_stockpile_id(game_state: GameState, worker_entity: Dictionary) -> int:
	var owner_id: int = game_state.get_entity_owner_id(worker_entity)
	var worker_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var best_stockpile_id: int = 0
	var best_distance: int = 0

	for entity_id in game_state.get_entities_by_type("stockpile"):
		var stockpile_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(stockpile_entity) != owner_id:
			continue

		var stockpile_cell: Vector2i = game_state.get_entity_grid_position(stockpile_entity)
		var distance: int = absi(stockpile_cell.x - worker_cell.x) + absi(stockpile_cell.y - worker_cell.y)
		if best_stockpile_id == 0 or distance < best_distance or (
			distance == best_distance and entity_id < best_stockpile_id
		):
			best_stockpile_id = entity_id
			best_distance = distance

	return best_stockpile_id


func _find_path_avoid_occupied(
	game_state: GameState,
	from_cell: Vector2i,
	to_cell: Vector2i
) -> Array[Vector2i]:
	var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state, from_cell, to_cell, true
	)
	if not path_cells.is_empty() or from_cell == to_cell:
		return path_cells
	return DeterministicPathfinderClass.find_path(game_state, from_cell, to_cell, false)
