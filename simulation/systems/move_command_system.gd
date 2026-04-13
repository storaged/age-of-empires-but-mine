class_name MoveCommandSystem
extends SimulationSystem

const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")

## Applies move command intent to authoritative unit state.


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type != "move_unit":
			continue

		if not (command is MoveUnitCommand):
			continue

		var move_command: MoveUnitCommand = command
		if not game_state.entities.has(move_command.unit_id):
			continue

		var entity: Dictionary = game_state.get_entity_dict(move_command.unit_id)
		if game_state.get_entity_type(entity) != "unit":
			continue

		var target_cell: Vector2i = move_command.target_cell
		if not game_state.is_cell_walkable(target_cell):
			continue

		var current_cell: Vector2i = game_state.get_entity_grid_position(entity)
		var path_cells: Array[Vector2i] = DeterministicPathfinderClass.find_path(
			game_state,
			current_cell,
			target_cell
		)
		if current_cell != target_cell and path_cells.is_empty():
			entity["path_cells"] = []
			entity["has_move_target"] = false
			entity["worker_task_state"] = "idle"
			entity["assigned_resource_node_id"] = 0
			entity["assigned_stockpile_id"] = 0
			entity["assigned_construction_site_id"] = 0
			entity["gather_progress_ticks"] = 0
			entity["interaction_slot_cell"] = Vector2i(-1, -1)
			if entity.has("attack_target_id"):
				entity["attack_target_id"] = 0
				entity["attack_cooldown_remaining"] = 0
			entity["attack_move_target_cell"] = Vector2i(-1, -1)
			game_state.entities[move_command.unit_id] = entity
			continue

		entity["move_target"] = target_cell
		entity["path_cells"] = path_cells
		entity["has_move_target"] = not path_cells.is_empty()
		entity["worker_task_state"] = "idle"
		entity["assigned_resource_node_id"] = 0
		entity["assigned_stockpile_id"] = 0
		entity["assigned_construction_site_id"] = 0
		entity["gather_progress_ticks"] = 0
		entity["interaction_slot_cell"] = Vector2i(-1, -1)
		if entity.has("attack_target_id"):
			entity["attack_target_id"] = 0
			entity["attack_cooldown_remaining"] = 0
		entity["attack_move_target_cell"] = Vector2i(-1, -1)
		game_state.entities[move_command.unit_id] = entity
