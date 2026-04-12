class_name BuildCommandSystem
extends SimulationSystem

const BuildStructureCommandClass = preload("res://commands/build_structure_command.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")
const QueueProductionCommandClass = preload("res://commands/queue_production_command.gd")


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type == "build_structure":
			_apply_build_structure_command(game_state, command)
			continue
		if command.command_type == "queue_production":
			_apply_queue_production_command(game_state, command)


func _apply_build_structure_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is BuildStructureCommandClass):
		return

	var build_command: BuildStructureCommandClass = command
	if not game_state.entities.has(build_command.builder_unit_id):
		return

	var builder_entity: Dictionary = game_state.get_entity_dict(build_command.builder_unit_id)
	if game_state.get_entity_type(builder_entity) != "unit":
		return
	if game_state.get_entity_unit_role(builder_entity) != "worker":
		return

	var build_cost: int = game_state.get_structure_cost(build_command.structure_type)
	var build_duration: int = game_state.get_structure_construction_duration(build_command.structure_type)
	if build_cost <= 0 or build_duration <= 0:
		return
	if game_state.get_resource_amount("wood") < build_cost:
		return
	if not game_state.can_place_structure_at(build_command.target_cell):
		return

	var structure_id: int = game_state.allocate_entity_id()
	var owner_id: int = game_state.get_entity_owner_id(builder_entity, 1)
	var structure_entity: Dictionary = {
		"id": structure_id,
		"entity_type": "structure",
		"structure_type": build_command.structure_type,
		"owner_id": owner_id,
		"grid_position": build_command.target_cell,
		"is_constructed": false,
		"construction_progress_ticks": 0,
		"construction_duration_ticks": build_duration,
		"assigned_builder_id": build_command.builder_unit_id,
	}
	game_state.entities[structure_id] = structure_entity
	game_state.resources["wood"] = game_state.get_resource_amount("wood") - build_cost

	var slot_cell: Vector2i = game_state.get_interaction_slot_for_worker(
		build_command.target_cell,
		"assigned_construction_site_id",
		structure_id,
		build_command.builder_unit_id,
		["to_construction", "constructing"]
	)
	if slot_cell == Vector2i(-1, -1):
		game_state.entities.erase(structure_id)
		game_state.resources["wood"] = game_state.get_resource_amount("wood") + build_cost
		return

	var current_cell: Vector2i = game_state.get_entity_grid_position(builder_entity)
	var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state,
		current_cell,
		slot_cell
	)
	if current_cell != slot_cell and path_cells.is_empty():
		game_state.entities.erase(structure_id)
		game_state.resources["wood"] = game_state.get_resource_amount("wood") + build_cost
		return

	builder_entity["assigned_resource_node_id"] = 0
	builder_entity["assigned_stockpile_id"] = 0
	builder_entity["assigned_construction_site_id"] = structure_id
	builder_entity["gather_progress_ticks"] = 0
	builder_entity["worker_task_state"] = "to_construction"
	builder_entity["path_cells"] = path_cells
	builder_entity["has_move_target"] = not path_cells.is_empty()
	builder_entity["move_target"] = slot_cell
	builder_entity["interaction_slot_cell"] = slot_cell
	game_state.entities[build_command.builder_unit_id] = builder_entity


func _apply_queue_production_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is QueueProductionCommandClass):
		return

	var production_command: QueueProductionCommandClass = command
	if not game_state.entities.has(production_command.producer_entity_id):
		return

	var producer_entity: Dictionary = game_state.get_entity_dict(production_command.producer_entity_id)
	var producer_type: String = game_state.get_entity_type(producer_entity)
	if producer_type != "stockpile" and producer_type != "structure":
		return
	if producer_type == "structure" and not game_state.get_entity_is_constructed(producer_entity):
		return

	var production_cost: int = game_state.get_production_cost(production_command.produced_unit_type)
	var production_duration: int = game_state.get_production_duration(production_command.produced_unit_type)
	if production_cost <= 0 or production_duration <= 0:
		return
	if game_state.get_resource_amount("wood") < production_cost:
		return

	game_state.resources["wood"] = game_state.get_resource_amount("wood") - production_cost
	var queue_count: int = game_state.get_entity_production_queue_count(producer_entity) + 1
	producer_entity["production_queue_count"] = queue_count
	producer_entity["produced_unit_type"] = production_command.produced_unit_type
	producer_entity["production_duration_ticks"] = production_duration
	if game_state.get_entity_production_progress_ticks(producer_entity) <= 0:
		producer_entity["production_progress_ticks"] = 0
	producer_entity["production_blocked"] = false
	game_state.entities[production_command.producer_entity_id] = producer_entity
