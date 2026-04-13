class_name StructureEconomySystem
extends SimulationSystem


func apply(game_state: GameState, _commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	var structure_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("stockpile"):
		structure_ids.append(entity_id)
	for entity_id in game_state.get_entities_by_type("structure"):
		structure_ids.append(entity_id)
	structure_ids.sort()

	for structure_id in structure_ids:
		var structure_entity: Dictionary = game_state.get_entity_dict(structure_id)
		if not game_state.get_entity_is_constructed(structure_entity):
			continue

		var trickle_type: String = game_state.get_entity_resource_trickle_type(structure_entity)
		var trickle_amount: int = game_state.get_entity_resource_trickle_amount(structure_entity)
		var trickle_interval: int = game_state.get_entity_resource_trickle_interval_ticks(structure_entity)
		if trickle_type == "" or trickle_amount <= 0 or trickle_interval <= 0:
			continue

		var progress: int = game_state.get_entity_resource_trickle_progress_ticks(structure_entity) + 1
		if progress < trickle_interval:
			structure_entity["resource_trickle_progress_ticks"] = progress
			game_state.entities[structure_id] = structure_entity
			continue

		structure_entity["resource_trickle_progress_ticks"] = 0
		game_state.resources[trickle_type] = game_state.get_resource_amount(trickle_type) + trickle_amount
		game_state.entities[structure_id] = structure_entity
