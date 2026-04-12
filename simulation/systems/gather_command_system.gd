class_name GatherCommandSystem
extends SimulationSystem

const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")
const ReturnCargoCommandClass = preload("res://commands/return_cargo_command.gd")


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type == "return_cargo":
			_apply_return_cargo_command(game_state, command)
			continue

		if command.command_type != "gather_resource":
			continue
		if not (command is GatherResourceCommand):
			continue

		var gather_command: GatherResourceCommand = command
		if not game_state.entities.has(gather_command.unit_id):
			continue
		if not game_state.entities.has(gather_command.resource_node_id):
			continue

		var worker_entity: Dictionary = game_state.get_entity_dict(gather_command.unit_id)
		var resource_entity: Dictionary = game_state.get_entity_dict(gather_command.resource_node_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue
		if game_state.get_entity_type(resource_entity) != "resource_node":
			continue
		if game_state.get_entity_remaining_amount(resource_entity) <= 0:
			continue

		var stockpile_id: int = _find_best_stockpile_id(game_state, worker_entity)
		if stockpile_id == 0:
			continue

		worker_entity["assigned_resource_node_id"] = gather_command.resource_node_id
		worker_entity["assigned_stockpile_id"] = stockpile_id
		worker_entity["assigned_construction_site_id"] = 0
		worker_entity["gather_progress_ticks"] = 0
		worker_entity["move_target"] = game_state.get_entity_grid_position(worker_entity)

		var carried_amount: int = game_state.get_entity_carried_amount(worker_entity)
		if carried_amount > 0:
			_assign_path_to_stockpile(game_state, gather_command.unit_id, worker_entity, stockpile_id)
		else:
			_assign_path_to_resource(game_state, gather_command.unit_id, worker_entity, gather_command.resource_node_id)

		game_state.entities[gather_command.unit_id] = worker_entity


func _apply_return_cargo_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is ReturnCargoCommandClass):
		return

	var return_command: ReturnCargoCommandClass = command
	if not game_state.entities.has(return_command.unit_id):
		return
	if not game_state.entities.has(return_command.stockpile_id):
		return

	var worker_entity: Dictionary = game_state.get_entity_dict(return_command.unit_id)
	var stockpile_entity: Dictionary = game_state.get_entity_dict(return_command.stockpile_id)
	if game_state.get_entity_type(worker_entity) != "unit":
		return
	if game_state.get_entity_unit_role(worker_entity) != "worker":
		return
	if game_state.get_entity_type(stockpile_entity) != "stockpile":
		return
	if game_state.get_entity_carried_amount(worker_entity) <= 0:
		return

	worker_entity["assigned_resource_node_id"] = 0
	worker_entity["assigned_stockpile_id"] = return_command.stockpile_id
	worker_entity["assigned_construction_site_id"] = 0
	worker_entity["gather_progress_ticks"] = 0
	worker_entity["move_target"] = game_state.get_entity_grid_position(worker_entity)
	_assign_path_to_stockpile(game_state, return_command.unit_id, worker_entity, return_command.stockpile_id)
	game_state.entities[return_command.unit_id] = worker_entity


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


func _assign_path_to_resource(
	game_state: GameState,
	worker_id: int,
	worker_entity: Dictionary,
	resource_node_id: int
) -> void:
	var current_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var resource_entity: Dictionary = game_state.get_entity_dict(resource_node_id)
	var resource_cell: Vector2i = game_state.get_entity_grid_position(resource_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		resource_cell,
		"assigned_resource_node_id",
		resource_node_id,
		worker_id,
		["to_resource", "gathering"]
	)
	if slot_cell == Vector2i(-1, -1):
		_clear_worker_task(worker_entity, current_cell)
		return
	var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state,
		current_cell,
		slot_cell
	)
	if current_cell != slot_cell and path_cells.is_empty():
		_clear_worker_task(worker_entity, current_cell)
		return
	worker_entity["path_cells"] = path_cells
	worker_entity["has_move_target"] = not path_cells.is_empty()
	worker_entity["worker_task_state"] = "to_resource"
	worker_entity["move_target"] = slot_cell
	worker_entity["interaction_slot_cell"] = slot_cell


func _assign_path_to_stockpile(
	game_state: GameState,
	worker_id: int,
	worker_entity: Dictionary,
	stockpile_id: int
) -> void:
	var current_cell: Vector2i = game_state.get_entity_grid_position(worker_entity)
	var stockpile_entity: Dictionary = game_state.get_entity_dict(stockpile_id)
	var stockpile_cell: Vector2i = game_state.get_entity_grid_position(stockpile_entity)
	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		stockpile_cell,
		"assigned_stockpile_id",
		stockpile_id,
		worker_id,
		["to_stockpile", "depositing"]
	)
	if slot_cell == Vector2i(-1, -1):
		_clear_worker_task(worker_entity, current_cell)
		return
	var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state,
		current_cell,
		slot_cell
	)
	if current_cell != slot_cell and path_cells.is_empty():
		_clear_worker_task(worker_entity, current_cell)
		return
	worker_entity["path_cells"] = path_cells
	worker_entity["has_move_target"] = not path_cells.is_empty()
	worker_entity["worker_task_state"] = "to_stockpile"
	worker_entity["move_target"] = slot_cell
	worker_entity["interaction_slot_cell"] = slot_cell


func _clear_worker_task(worker_entity: Dictionary, worker_cell: Vector2i) -> void:
	worker_entity["worker_task_state"] = "idle"
	worker_entity["assigned_resource_node_id"] = 0
	worker_entity["assigned_stockpile_id"] = 0
	worker_entity["assigned_construction_site_id"] = 0
	worker_entity["gather_progress_ticks"] = 0
	worker_entity["path_cells"] = []
	worker_entity["has_move_target"] = false
	worker_entity["move_target"] = worker_cell
	worker_entity["interaction_slot_cell"] = Vector2i(-1, -1)
