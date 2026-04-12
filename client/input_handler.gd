class_name InputHandler
extends RefCounted

const AssignConstructionCommandClass = preload("res://commands/assign_construction_command.gd")
const AttackCommandClass = preload("res://commands/attack_command.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const BuildStructureCommandClass = preload("res://commands/build_structure_command.gd")
const GatherResourceCommandClass = preload("res://commands/gather_resource_command.gd")
const MoveUnitCommandClass = preload("res://commands/move_unit_command.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")
const ReturnCargoCommandClass = preload("res://commands/return_cargo_command.gd")

## Converts local input into validated command objects and client-only selection state.

var issuer_id: int = 1
var next_sequence_number: int = 0


func select_unit_at_world_position(
	world_position: Vector2,
	game_state: GameState,
	client_state: ClientState,
	cell_size: int
) -> void:
	var selected_entity_id: int = _find_selectable_entity_at_world_position(
		world_position,
		game_state,
		client_state,
		cell_size
	)

	if selected_entity_id == -1:
		client_state.clear_selection()
		return

	client_state.set_selection([selected_entity_id])


func build_commands_for_world_position(
	world_position: Vector2,
	game_state: GameState,
	client_state: ClientState,
	cell_size: int,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	var clamped_target_cell: Vector2i = _clamp_cell_to_map(
		_world_to_cell(world_position, cell_size),
		game_state
	)
	if client_state.is_in_structure_placement_mode():
		return _build_structure_commands_for_cell(
			clamped_target_cell,
			game_state,
			client_state,
			scheduled_tick
		)

	if client_state.selected_entity_ids.is_empty():
		client_state.set_order_feedback("No units selected.", true)
		return []

	var resource_node_id: int = _find_resource_node_id_at_cell(clamped_target_cell, game_state)
	if resource_node_id != 0:
		return _build_gather_commands_for_resource_node(
			resource_node_id,
			clamped_target_cell,
			game_state,
			client_state,
			scheduled_tick
		)

	var stockpile_id: int = _find_stockpile_id_at_cell(clamped_target_cell, game_state)
	if stockpile_id != 0:
		return _build_return_cargo_commands_for_stockpile(
			stockpile_id,
			clamped_target_cell,
			game_state,
			client_state,
			scheduled_tick
		)

	var unfinished_structure_id: int = _find_unfinished_structure_id_at_cell(clamped_target_cell, game_state)
	if unfinished_structure_id != 0:
		return _build_assign_construction_commands(
			unfinished_structure_id,
			clamped_target_cell,
			game_state,
			client_state,
			scheduled_tick
		)

	var enemy_id: int = _find_enemy_entity_id_at_cell(clamped_target_cell, game_state)
	if enemy_id != 0:
		return _build_attack_commands(
			enemy_id,
			clamped_target_cell,
			game_state,
			client_state,
			scheduled_tick
		)

	if not game_state.is_cell_walkable(clamped_target_cell):
		client_state.set_invalid_indicator(clamped_target_cell, "Blocked cell. Order rejected.")
		return []

	var commands: Array[SimulationCommand] = []
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()
	var target_cells: Array[Vector2i] = _build_group_target_cells(
		clamped_target_cell,
		sorted_unit_ids,
		game_state
	)

	if target_cells.is_empty():
		client_state.set_invalid_indicator(clamped_target_cell, "Destination unreachable.")
		return []

	for index in range(target_cells.size()):
		var unit_id_value: Variant = sorted_unit_ids[index]
		if not (unit_id_value is int):
			continue
		var unit_id: int = unit_id_value
		var target_cell_value: Variant = target_cells[index]
		if not (target_cell_value is Vector2i):
			continue
		var target_cell: Vector2i = target_cell_value
		commands.append(
			MoveUnitCommandClass.new(
				scheduled_tick,
				issuer_id,
				_next_sequence_number(),
				unit_id,
				target_cell
			)
		)

	client_state.set_move_indicators(target_cells)
	var carrying_units_selected: bool = _selection_contains_carrying_worker(game_state, client_state)
	if target_cells.size() == sorted_unit_ids.size():
		if carrying_units_selected:
			client_state.set_order_feedback("Move order accepted. Cargo preserved.", false)
		else:
			client_state.set_order_feedback("Move order accepted.", false)
	else:
		client_state.set_order_feedback(
			"Move order accepted for %d/%d units." % [target_cells.size(), sorted_unit_ids.size()],
			false
		)
	return commands


func build_production_commands_for_selection(
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	if client_state.selected_entity_ids.size() != 1:
		client_state.set_order_feedback("Select one producer to queue production.", true)
		return []

	var selected_id: int = client_state.selected_entity_ids[0]
	var selected_entity: Dictionary = game_state.get_entity_dict(selected_id)
	var entity_type: String = game_state.get_entity_type(selected_entity)

	var produced_unit_type: String = ""
	if entity_type == "stockpile":
		produced_unit_type = GameDefinitionsClass.get_stockpile_produces()
	elif entity_type == "structure":
		if not game_state.get_entity_is_constructed(selected_entity):
			client_state.set_order_feedback("Building not yet constructed.", true)
			return []
		var structure_type: String = game_state.get_entity_structure_type(selected_entity)
		produced_unit_type = GameDefinitionsClass.get_building_produces(structure_type)
		if produced_unit_type == "":
			client_state.set_order_feedback("This building cannot produce units.", true)
			return []
	else:
		client_state.set_order_feedback("Select a base or barracks to produce units.", true)
		return []

	if not game_state.can_afford_production(produced_unit_type):
		var costs_str: String = GameDefinitionsClass.format_costs(
			GameDefinitionsClass.get_unit_production_costs(produced_unit_type)
		)
		var unit_name: String = GameDefinitionsClass.get_unit_display_name(produced_unit_type)
		client_state.set_order_feedback(
			"Not enough resources to produce a %s (%s)." % [unit_name.to_lower(), costs_str],
			true
		)
		return []

	var commands: Array[SimulationCommand] = []
	commands.append(
		QueueProductionCommandClass.new(
			scheduled_tick,
			issuer_id,
			_next_sequence_number(),
			selected_id,
			produced_unit_type
		)
	)
	client_state.set_order_feedback("%s production queued." % produced_unit_type.capitalize(), false)
	return commands


func _build_gather_commands_for_resource_node(
	resource_node_id: int,
	resource_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	var resource_node: Dictionary = game_state.get_entity_dict(resource_node_id)
	if game_state.get_entity_remaining_amount(resource_node) <= 0:
		client_state.set_invalid_indicator(resource_cell, "Resource depleted.")
		return []

	var commands: Array[SimulationCommand] = []
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()

	for unit_id in sorted_unit_ids:
		var worker_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue

		commands.append(
			GatherResourceCommandClass.new(
				scheduled_tick,
				issuer_id,
				_next_sequence_number(),
				unit_id,
				resource_node_id
			)
		)

	if commands.is_empty():
		client_state.set_invalid_indicator(resource_cell, "Selected units cannot gather.")
		return []

	client_state.set_gather_indicator(resource_cell)
	client_state.set_order_feedback("Gather order accepted.", false)
	return commands


func _find_enemy_entity_id_at_cell(cell: Vector2i, game_state: GameState) -> int:
	var cell_key_str: String = "%d,%d" % [cell.x, cell.y]
	if game_state.occupancy.has(cell_key_str):
		var occ: Variant = game_state.occupancy[cell_key_str]
		if occ is int:
			var unit_entity: Dictionary = game_state.get_entity_dict(occ)
			if game_state.get_entity_owner_id(unit_entity) != issuer_id:
				return occ
	for entity_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(structure_entity) == cell:
			if game_state.get_entity_owner_id(structure_entity) != issuer_id:
				return entity_id
	return 0


func _build_attack_commands(
	target_id: int,
	target_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	var commands: Array[SimulationCommand] = []
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()

	for unit_id in sorted_unit_ids:
		var entity: Dictionary = game_state.get_entity_dict(unit_id)
		if not game_state.get_entity_can_attack(entity):
			continue
		commands.append(
			AttackCommandClass.new(
				scheduled_tick, issuer_id, _next_sequence_number(),
				unit_id, target_id
			)
		)

	if commands.is_empty():
		client_state.set_invalid_indicator(target_cell, "Select combat units to attack.")
		return []

	client_state.set_attack_indicator(target_cell)
	client_state.set_order_feedback("Attack order accepted.", false)
	return commands


func _find_unfinished_structure_id_at_cell(cell: Vector2i, game_state: GameState) -> int:
	for entity_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(structure_entity) == cell:
			if not game_state.get_entity_is_constructed(structure_entity):
				return entity_id
	return 0


func _build_assign_construction_commands(
	structure_id: int,
	structure_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	var commands: Array[SimulationCommand] = []
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()

	for unit_id in sorted_unit_ids:
		var worker_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue
		commands.append(
			AssignConstructionCommandClass.new(
				scheduled_tick, issuer_id, _next_sequence_number(),
				unit_id, structure_id
			)
		)
		break  # single-builder model

	if commands.is_empty():
		client_state.set_invalid_indicator(structure_cell, "Select a worker to resume construction.")
		return []

	client_state.set_order_feedback("Construction assigned.", false)
	return commands


func _build_return_cargo_commands_for_stockpile(
	stockpile_id: int,
	stockpile_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	var commands: Array[SimulationCommand] = []
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()

	for unit_id in sorted_unit_ids:
		var worker_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue
		if game_state.get_entity_carried_amount(worker_entity) <= 0:
			continue

		commands.append(
			ReturnCargoCommandClass.new(
				scheduled_tick,
				issuer_id,
				_next_sequence_number(),
				unit_id,
				stockpile_id
			)
		)

	if commands.is_empty():
		client_state.set_invalid_indicator(stockpile_cell, "Only carrying workers can deposit.")
		return []

	client_state.set_return_indicator(stockpile_cell)
	client_state.set_order_feedback("Return cargo order accepted.", false)
	return commands


func update_hover_from_world_position(
	world_position: Vector2,
	game_state: GameState,
	client_state: ClientState,
	cell_size: int
) -> void:
	client_state.set_hover_cell(
		_clamp_cell_to_map(_world_to_cell(world_position, cell_size), game_state)
	)
	if client_state.is_in_structure_placement_mode():
		var preview_cell: Vector2i = client_state.hover_cell
		var can_place: bool = _can_place_structure(
			preview_cell,
			game_state,
			client_state
		)
		client_state.set_placement_preview(
			preview_cell,
			can_place,
			_build_placement_reason(preview_cell, game_state, client_state, can_place)
		)

	client_state.set_hovered_entity_id(
		_find_selectable_entity_at_world_position(world_position, game_state, client_state, cell_size)
	)


func build_selection_for_world_rect(
	world_rect: Rect2,
	game_state: GameState,
	client_state: ClientState,
	cell_size: int
) -> Array[int]:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	var selected_ids: Array[int] = []

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue

		var grid_position: Vector2i = game_state.get_entity_grid_position(entity)
		var authoritative_center: Vector2 = Vector2(
			(grid_position.x + 0.5) * cell_size,
			(grid_position.y + 0.5) * cell_size
		)
		var visual_position: Vector2 = client_state.get_visual_unit_world_position(entity_id, authoritative_center)
		if world_rect.has_point(visual_position):
			selected_ids.append(entity_id)

	return selected_ids


func _build_structure_commands_for_cell(
	target_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	scheduled_tick: int
) -> Array[SimulationCommand]:
	if not _can_place_structure(target_cell, game_state, client_state):
		client_state.set_invalid_indicator(
			target_cell,
			_build_placement_reason(target_cell, game_state, client_state, false)
		)
		return []

	var builder_unit_id: int = _find_primary_builder_id(game_state, client_state)
	if builder_unit_id == 0:
		client_state.set_invalid_indicator(target_cell, "Select a worker to build.")
		return []

	var commands: Array[SimulationCommand] = []
	commands.append(
		BuildStructureCommandClass.new(
			scheduled_tick,
			issuer_id,
			_next_sequence_number(),
			builder_unit_id,
			client_state.placement_mode_structure_type,
			target_cell
		)
	)
	client_state.set_build_indicator(target_cell)
	var placed_display: String = GameDefinitionsClass.get_building_display_name(
		client_state.placement_mode_structure_type
	)
	client_state.set_order_feedback("%s build order accepted." % placed_display, false)
	client_state.cancel_structure_placement()
	return commands


func _world_to_cell(world_position: Vector2, cell_size: int) -> Vector2i:
	return Vector2i(
		floori(world_position.x / float(cell_size)),
		floori(world_position.y / float(cell_size))
	)


func _find_selectable_entity_at_world_position(
	world_position: Vector2,
	game_state: GameState,
	client_state: ClientState,
	cell_size: int
) -> int:
	var unit_ids: Array[int] = game_state.get_entities_by_type("unit")
	var selection_radius: float = float(cell_size) * 0.52

	for entity_id in unit_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var grid_position: Vector2i = game_state.get_entity_grid_position(entity, Vector2i(-1, -1))
		var authoritative_center: Vector2 = Vector2(
			(grid_position.x + 0.5) * cell_size,
			(grid_position.y + 0.5) * cell_size
		)
		var visual_position: Vector2 = client_state.get_visual_unit_world_position(entity_id, authoritative_center)
		if visual_position.distance_to(world_position) <= selection_radius:
			return entity_id

	var target_cell: Vector2i = _clamp_cell_to_map(_world_to_cell(world_position, cell_size), game_state)
	var static_entity_id: int = game_state.get_selectable_entity_id_at_cell(target_cell)
	if static_entity_id != 0:
		return static_entity_id

	return -1


func _find_resource_node_id_at_cell(cell: Vector2i, game_state: GameState) -> int:
	for entity_id in game_state.get_entities_by_type("resource_node"):
		var resource_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(resource_entity) == cell:
			return entity_id
	return 0


func _find_stockpile_id_at_cell(cell: Vector2i, game_state: GameState) -> int:
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var stockpile_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(stockpile_entity) == cell:
			return entity_id
	return 0


func _selection_contains_carrying_worker(game_state: GameState, client_state: ClientState) -> bool:
	for unit_id in client_state.selected_entity_ids:
		var worker_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_carried_amount(worker_entity) > 0:
			return true
	return false


func _find_primary_builder_id(game_state: GameState, client_state: ClientState) -> int:
	var sorted_unit_ids: Array[int] = []
	for unit_id in client_state.selected_entity_ids:
		sorted_unit_ids.append(unit_id)
	sorted_unit_ids.sort()
	for unit_id in sorted_unit_ids:
		var worker_entity: Dictionary = game_state.get_entity_dict(unit_id)
		if game_state.get_entity_type(worker_entity) != "unit":
			continue
		if game_state.get_entity_unit_role(worker_entity) != "worker":
			continue
		return unit_id
	return 0


func _can_place_structure(
	target_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState
) -> bool:
	if client_state.placement_mode_structure_type == "":
		return false
	if not game_state.can_place_structure_at(target_cell):
		return false
	if not game_state.is_prerequisite_met(client_state.placement_mode_structure_type):
		return false
	if not game_state.can_afford_building(client_state.placement_mode_structure_type):
		return false
	if _find_primary_builder_id(game_state, client_state) == 0:
		return false
	return true


func _build_placement_reason(
	target_cell: Vector2i,
	game_state: GameState,
	client_state: ClientState,
	can_place: bool
) -> String:
	var structure_type: String = client_state.placement_mode_structure_type
	var display_name: String = GameDefinitionsClass.get_building_display_name(structure_type)
	if can_place:
		return "%s placement valid." % display_name
	if _find_primary_builder_id(game_state, client_state) == 0:
		return "Select a worker to build."
	var prereq: String = GameDefinitionsClass.get_building_prerequisite(structure_type)
	if prereq != "" and not game_state.is_prerequisite_met(structure_type):
		var prereq_name: String = GameDefinitionsClass.get_building_display_name(prereq)
		return "Requires a completed %s first." % prereq_name
	if not game_state.can_afford_building(structure_type):
		var costs_str: String = GameDefinitionsClass.format_costs(
			GameDefinitionsClass.get_building_costs(structure_type)
		)
		return "Not enough resources (%s)." % costs_str
	if game_state.is_cell_occupied_by_unit(target_cell):
		return "Cannot place on a unit."
	if game_state.has_static_blocker_at_cell(target_cell):
		return "Cell occupied by terrain or structure."
	if not game_state.is_cell_walkable(target_cell):
		return "Blocked terrain."
	return "Invalid build location."


func _clamp_cell_to_map(cell: Vector2i, game_state: GameState) -> Vector2i:
	var width: int = maxi(game_state.get_map_width(), 1)
	var height: int = maxi(game_state.get_map_height(), 1)

	return Vector2i(
		clampi(cell.x, 0, width - 1),
		clampi(cell.y, 0, height - 1)
	)


func _next_sequence_number() -> int:
	var sequence_number: int = next_sequence_number
	next_sequence_number += 1
	return sequence_number


func _build_group_target_cells(
	center_cell: Vector2i,
	sorted_unit_ids: Array[int],
	game_state: GameState
) -> Array[Vector2i]:
	var assigned_cells: Array[Vector2i] = []
	var used_cells: Dictionary = {}
	var candidate_cells: Array[Vector2i] = _build_candidate_target_cells(center_cell, game_state)

	for unit_id in sorted_unit_ids:
		if not game_state.entities.has(unit_id):
			continue

		var entity: Dictionary = game_state.get_entity_dict(unit_id)
		var start_cell: Vector2i = game_state.get_entity_grid_position(entity)

		for candidate_cell in candidate_cells:
			var cell_key: String = "%d,%d" % [candidate_cell.x, candidate_cell.y]
			if used_cells.has(cell_key):
				continue

			var path: Array[Vector2i] = DeterministicPathfinderClass.find_path(
				game_state,
				start_cell,
				candidate_cell
			)
			if candidate_cell != start_cell and path.is_empty():
				continue

			used_cells[cell_key] = true
			assigned_cells.append(candidate_cell)
			break

	return assigned_cells


func _build_candidate_target_cells(center_cell: Vector2i, game_state: GameState) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var used_cells: Dictionary = {}
	var width: int = maxi(game_state.get_map_width(), 1)
	var height: int = maxi(game_state.get_map_height(), 1)
	var max_radius: int = maxi(width, height)

	for search_radius in range(max_radius + 1):
		for offset in _offsets_for_radius(search_radius):
			var candidate_cell: Vector2i = _clamp_cell_to_map(center_cell + offset, game_state)
			var cell_key: String = "%d,%d" % [candidate_cell.x, candidate_cell.y]
			if used_cells.has(cell_key):
				continue
			if not game_state.is_cell_walkable(candidate_cell):
				continue

			used_cells[cell_key] = true
			candidates.append(candidate_cell)

	return candidates


func _offsets_for_radius(radius: int) -> Array[Vector2i]:
	if radius == 0:
		var center_only: Array[Vector2i] = []
		center_only.append(Vector2i.ZERO)
		return center_only

	var offsets: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if max(abs(x), abs(y)) != radius:
				continue
			offsets.append(Vector2i(x, y))

	offsets.sort_custom(Callable(self, "_sort_offsets"))
	return offsets


func _sort_offsets(left: Vector2i, right: Vector2i) -> bool:
	var left_key: Array[int] = [absi(left.x) + absi(left.y), left.y, left.x]
	var right_key: Array[int] = [absi(right.x) + absi(right.y), right.y, right.x]
	return left_key < right_key
