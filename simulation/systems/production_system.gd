class_name ProductionSystem
extends SimulationSystem


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
	if produced_unit_type != "worker":
		return

	var unit_id: int = game_state.allocate_entity_id()
	game_state.entities[unit_id] = {
		"id": unit_id,
		"entity_type": "unit",
		"unit_role": "worker",
		"owner_id": game_state.get_entity_owner_id(producer_entity, 1),
		"grid_position": spawn_cell,
		"move_target": spawn_cell,
		"path_cells": [],
		"has_move_target": false,
		"worker_task_state": "idle",
		"assigned_resource_node_id": 0,
		"assigned_stockpile_id": producer_id,
		"assigned_construction_site_id": 0,
		"carried_resource_type": "",
		"carried_amount": 0,
		"interaction_slot_cell": Vector2i(-1, -1),
		"traffic_state": "",
		"carry_capacity": 10,
		"harvest_amount": 5,
		"gather_duration_ticks": 8,
		"deposit_duration_ticks": 2,
		"gather_progress_ticks": 0,
	}
	game_state.occupancy[game_state.cell_key(spawn_cell)] = unit_id
