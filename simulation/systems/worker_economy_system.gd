class_name WorkerEconomySystem
extends SimulationSystem

const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")


func apply(game_state: GameState, _commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for entity_id in game_state.get_entities_by_type("unit"):
		var worker_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue

		var task_state: String = game_state.get_entity_task_state(worker_entity)
		if task_state == "idle":
			continue

		if task_state == "to_resource":
			_update_to_resource(game_state, entity_id, worker_entity)
			continue
		if task_state == "gathering":
			_update_gathering(game_state, entity_id, worker_entity)
			continue
		if task_state == "to_stockpile":
			_update_to_stockpile(game_state, entity_id, worker_entity)
			continue
		if task_state == "depositing":
			_update_depositing(game_state, entity_id, worker_entity)
			continue
		if task_state == "to_construction":
			_update_to_construction(game_state, entity_id, worker_entity)
			continue
		if task_state == "constructing":
			_update_constructing(game_state, entity_id, worker_entity)
			continue


func _update_to_resource(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(worker_entity)
	if resource_node_id == 0 or not game_state.entities.has(resource_node_id):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
	if game_state.get_entity_remaining_amount(resource_entity) <= 0:
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var worker_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(worker_entity)
	if worker_cell == interaction_slot:
		worker_entity["worker_task_state"] = "gathering"
		worker_entity["gather_progress_ticks"] = 0
		worker_entity["path_cells"] = []
		worker_entity["has_move_target"] = false
		worker_entity["move_target"] = worker_cell
		game_state.entities[entity_id] = worker_entity
		return

	if game_state.get_entity_path_cells(worker_entity).is_empty():
		_reassign_resource_slot(game_state, entity_id, worker_entity)


func _update_gathering(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(worker_entity)
	if resource_node_id == 0 or not game_state.entities.has(resource_node_id):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
	var remaining_amount: int = game_state.get_entity_remaining_amount(resource_entity)
	var carried_amount: int = game_state.get_entity_carried_amount(worker_entity)
	if remaining_amount <= 0:
		if carried_amount > 0:
			_assign_worker_to_stockpile(game_state, entity_id, worker_entity)
		else:
			_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var progress: int = game_state.get_entity_gather_progress(worker_entity) + 1
	worker_entity["gather_progress_ticks"] = progress
	var gather_duration_ticks: int = maxi(game_state.get_entity_gather_duration_ticks(worker_entity), 1)
	if progress < gather_duration_ticks:
		game_state.entities[entity_id] = worker_entity
		return

	var harvest_amount: int = maxi(game_state.get_entity_harvest_amount(worker_entity), 1)
	var carry_capacity: int = maxi(game_state.get_entity_capacity(worker_entity), 1)
	var free_capacity: int = maxi(carry_capacity - carried_amount, 0)
	var gathered_amount: int = mini(harvest_amount, mini(remaining_amount, free_capacity))
	if gathered_amount <= 0:
		_assign_worker_to_stockpile(game_state, entity_id, worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	resource_entity["remaining_amount"] = remaining_amount - gathered_amount
	worker_entity["carried_resource_type"] = game_state.get_entity_string(resource_entity, "resource_type", "wood")
	worker_entity["carried_amount"] = carried_amount + gathered_amount
	worker_entity["gather_progress_ticks"] = 0
	game_state.entities[resource_node_id] = resource_entity

	_assign_worker_to_stockpile(game_state, entity_id, worker_entity)
	game_state.entities[entity_id] = worker_entity


func _update_to_stockpile(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var stockpile_id: int = game_state.get_entity_assigned_stockpile_id(worker_entity)
	if stockpile_id == 0 or not game_state.entities.has(stockpile_id):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var worker_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(worker_entity)
	if worker_cell == interaction_slot:
		worker_entity["worker_task_state"] = "depositing"
		worker_entity["gather_progress_ticks"] = 0
		worker_entity["path_cells"] = []
		worker_entity["has_move_target"] = false
		worker_entity["move_target"] = worker_cell
		game_state.entities[entity_id] = worker_entity
		return

	if game_state.get_entity_path_cells(worker_entity).is_empty():
		_reassign_stockpile_slot(game_state, entity_id, worker_entity)


func _update_depositing(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var progress: int = game_state.get_entity_gather_progress(worker_entity) + 1
	worker_entity["gather_progress_ticks"] = progress
	var deposit_duration_ticks: int = maxi(game_state.get_entity_deposit_duration_ticks(worker_entity), 1)
	if progress < deposit_duration_ticks:
		game_state.entities[entity_id] = worker_entity
		return

	var carried_amount: int = game_state.get_entity_carried_amount(worker_entity)
	var carried_resource_type: String = game_state.get_entity_carried_resource_type(worker_entity)
	if carried_amount > 0 and carried_resource_type != "":
		var current_total: int = game_state.get_resource_amount(carried_resource_type)
		game_state.resources[carried_resource_type] = current_total + carried_amount

	worker_entity["carried_amount"] = 0
	worker_entity["carried_resource_type"] = ""
	worker_entity["gather_progress_ticks"] = 0

	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(worker_entity)
	if resource_node_id != 0 and game_state.entities.has(resource_node_id):
		var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
		if game_state.get_entity_remaining_amount(resource_entity) > 0:
			_assign_worker_to_resource(game_state, entity_id, worker_entity)
			game_state.entities[entity_id] = worker_entity
			return

	_set_worker_idle(worker_entity)
	game_state.entities[entity_id] = worker_entity


func _update_to_construction(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var structure_id: int = game_state.get_entity_assigned_construction_site_id(worker_entity)
	if structure_id == 0 or not game_state.entities.has(structure_id):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
	if game_state.get_entity_is_constructed(structure_entity):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var worker_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(worker_entity)
	if worker_cell == interaction_slot:
		worker_entity["worker_task_state"] = "constructing"
		worker_entity["gather_progress_ticks"] = 0
		worker_entity["path_cells"] = []
		worker_entity["has_move_target"] = false
		worker_entity["move_target"] = worker_cell
		game_state.entities[entity_id] = worker_entity
		return

	if game_state.get_entity_path_cells(worker_entity).is_empty():
		_reassign_construction_slot(game_state, entity_id, worker_entity)
		game_state.entities[entity_id] = worker_entity


func _update_constructing(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var structure_id: int = game_state.get_entity_assigned_construction_site_id(worker_entity)
	if structure_id == 0 or not game_state.entities.has(structure_id):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
	if game_state.get_entity_is_constructed(structure_entity):
		_set_worker_idle(worker_entity)
		game_state.entities[entity_id] = worker_entity
		return

	var progress: int = game_state.get_entity_construction_progress_ticks(structure_entity) + 1
	structure_entity["construction_progress_ticks"] = progress
	var duration: int = maxi(game_state.get_entity_construction_duration_ticks(structure_entity), 1)
	if progress >= duration:
		structure_entity["construction_progress_ticks"] = duration
		structure_entity["is_constructed"] = true
		structure_entity["assigned_builder_id"] = 0
		_set_worker_idle(worker_entity)
	else:
		worker_entity["gather_progress_ticks"] = progress

	game_state.entities[structure_id] = structure_entity
	game_state.entities[entity_id] = worker_entity


func _assign_worker_to_resource(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(worker_entity)
	if resource_node_id == 0 or not game_state.entities.has(resource_node_id):
		_set_worker_idle(worker_entity)
		return
	_reassign_resource_slot(game_state, entity_id, worker_entity)


func _assign_worker_to_stockpile(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var stockpile_id: int = game_state.get_entity_assigned_stockpile_id(worker_entity)
	if stockpile_id == 0 or not game_state.entities.has(stockpile_id):
		_set_worker_idle(worker_entity)
		return
	_reassign_stockpile_slot(game_state, entity_id, worker_entity)


func _reassign_construction_slot(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var structure_id: int = game_state.get_entity_assigned_construction_site_id(worker_entity)
	if structure_id == 0 or not game_state.entities.has(structure_id):
		_set_worker_idle(worker_entity)
		return
	var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
	if game_state.get_entity_is_constructed(structure_entity):
		_set_worker_idle(worker_entity)
		return
	var structure_cell: Vector2i = game_state.get_entity_grid_position(structure_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		structure_cell,
		"assigned_construction_site_id",
		structure_id,
		entity_id,
		["to_construction", "constructing"]
	)
	_assign_path_to_slot(game_state, worker_entity, slot_cell, "to_construction")


func _reassign_resource_slot(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var resource_node_id: int = game_state.get_entity_assigned_resource_node_id(worker_entity)
	if resource_node_id == 0 or not game_state.entities.has(resource_node_id):
		_set_worker_idle(worker_entity)
		return
	var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
	var resource_cell: Vector2i = game_state.get_entity_grid_position(resource_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		resource_cell,
		"assigned_resource_node_id",
		resource_node_id,
		entity_id,
		["to_resource", "gathering"]
	)
	_assign_path_to_slot(game_state, worker_entity, slot_cell, "to_resource")


func _reassign_stockpile_slot(game_state: GameState, entity_id: int, worker_entity: Dictionary) -> void:
	var stockpile_id: int = game_state.get_entity_assigned_stockpile_id(worker_entity)
	if stockpile_id == 0 or not game_state.entities.has(stockpile_id):
		_set_worker_idle(worker_entity)
		return
	var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
	var stockpile_cell: Vector2i = game_state.get_entity_grid_position(stockpile_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		stockpile_cell,
		"assigned_stockpile_id",
		stockpile_id,
		entity_id,
		["to_stockpile", "depositing"]
	)
	_assign_path_to_slot(game_state, worker_entity, slot_cell, "to_stockpile")


func _assign_path_to_slot(
	game_state: GameState,
	worker_entity: Dictionary,
	slot_cell: Vector2i,
	task_state: String
) -> void:
	var worker_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	if slot_cell == Vector2i(-1, -1):
		_set_worker_idle(worker_entity)
		return
	var path_cells: Array[Vector2i] = _find_path_avoid_occupied(game_state, worker_cell, slot_cell)
	if worker_cell != slot_cell and path_cells.is_empty():
		_set_worker_idle(worker_entity)
		return
	worker_entity["path_cells"] = path_cells
	worker_entity["has_move_target"] = not path_cells.is_empty()
	worker_entity["worker_task_state"] = task_state
	worker_entity["move_target"] = slot_cell
	worker_entity["interaction_slot_cell"] = slot_cell


## Tries occupancy-aware pathfinding first; falls back to standard BFS if no unobstructed path.
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


func _set_worker_idle(worker_entity: Dictionary) -> void:
	var worker_cell: Vector2i = Vector2i.ZERO
	if worker_entity.has("grid_position"):
		var grid_position_value: Variant = worker_entity["grid_position"]
		if grid_position_value is Vector2i:
			worker_cell = grid_position_value
	worker_entity["worker_task_state"] = "idle"
	worker_entity["assigned_resource_node_id"] = 0
	worker_entity["assigned_stockpile_id"] = 0
	worker_entity["assigned_construction_site_id"] = 0
	worker_entity["gather_progress_ticks"] = 0
	worker_entity["path_cells"] = []
	worker_entity["has_move_target"] = false
	worker_entity["move_target"] = worker_cell
	worker_entity["interaction_slot_cell"] = Vector2i(-1, -1)
