class_name ScenarioRuntime
extends SimulationSystem

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")


func apply(game_state: GameState, _commands_for_tick: Array[SimulationCommand], tick: int) -> void:
	if game_state.scenario_state.is_empty():
		return
	_update_objectives(game_state, tick)
	_fire_events(game_state, tick)
	_update_outcome(game_state, tick)


func _update_objectives(game_state: GameState, tick: int) -> void:
	var objectives: Array[Dictionary] = _get_objectives(game_state)
	var changed: bool = false
	for index in range(objectives.size()):
		var objective: Dictionary = objectives[index]
		if bool(objective.get("completed", false)):
			continue
		var condition: Dictionary = _get_dict(objective.get("condition", {}))
		if not _is_condition_met(game_state, condition, tick):
			continue
		objective["completed"] = true
		objective["completed_tick"] = tick
		objectives[index] = objective
		_append_alert(game_state, "success", "Objective complete: %s" % str(objective.get("text", "")), tick)
		changed = true
	if changed:
		game_state.scenario_state["objectives"] = objectives


func _fire_events(game_state: GameState, tick: int) -> void:
	var events: Array[Dictionary] = _get_events(game_state)
	var fired_ids: Array[String] = _get_string_array(game_state.scenario_state.get("fired_event_ids", []))
	var changed: bool = false
	for event in events:
		var event_id: String = str(event.get("id", ""))
		if event_id == "" or fired_ids.has(event_id):
			continue
		var trigger: Dictionary = _get_dict(event.get("trigger", {}))
		if not _is_condition_met(game_state, trigger, tick):
			continue
		_apply_actions(game_state, _get_dict_array(event.get("actions", [])), tick)
		fired_ids.append(event_id)
		changed = true
	if changed:
		fired_ids.sort()
		game_state.scenario_state["fired_event_ids"] = fired_ids


func _apply_actions(game_state: GameState, actions: Array[Dictionary], tick: int) -> void:
	for action in actions:
		var action_type: String = str(action.get("type", ""))
		if action_type == "alert":
			_append_alert(
				game_state,
				str(action.get("kind", "info")),
				str(action.get("text", "")),
				tick
			)
		elif action_type == "spawn_units":
			_spawn_units(game_state, action)


func _spawn_units(game_state: GameState, action: Dictionary) -> void:
	var owner_id: int = int(action.get("owner_id", 2))
	var unit_type: String = str(action.get("unit_type", "enemy_dummy"))
	var cells: Array[Vector2i] = _get_vector2i_array(action.get("cells", []))
	var attack_player_base: bool = bool(action.get("attack_player_base", false))
	var player_base_id: int = _find_stockpile_id(game_state, 1)
	for cell in cells:
		var spawn_cell: Vector2i = DeterministicPathfinderClass.find_nearest_valid_unit_spawn_cell(
			game_state,
			cell
		)
		if spawn_cell == DeterministicPathfinderClass.INVALID_CELL:
			continue
		var unit_id: int = game_state.allocate_entity_id()
		var entity: Dictionary = GameDefinitionsClass.create_unit_entity(unit_type, unit_id, owner_id, spawn_cell, 0)
		if attack_player_base and player_base_id != 0:
			entity["attack_target_id"] = player_base_id
			entity["worker_task_state"] = "to_target"
		game_state.entities[unit_id] = entity
		game_state.occupancy[game_state.cell_key(spawn_cell)] = unit_id


func _update_outcome(game_state: GameState, tick: int) -> void:
	if game_state.win_condition_met or game_state.lose_condition_met:
		return
	var victory: Dictionary = _get_dict(game_state.scenario_state.get("victory_condition", {}))
	var defeat: Dictionary = _get_dict(game_state.scenario_state.get("defeat_condition", {}))
	if not defeat.is_empty() and _is_condition_met(game_state, defeat, tick):
		game_state.lose_condition_met = true
		_append_alert(game_state, "danger", "Mission failed.", tick)
		return
	if not victory.is_empty() and _is_condition_met(game_state, victory, tick):
		game_state.win_condition_met = true
		_append_alert(game_state, "success", "Mission complete.", tick)


func _is_condition_met(game_state: GameState, condition: Dictionary, tick: int) -> bool:
	var condition_type: String = str(condition.get("type", ""))
	if condition_type == "tick_at_least":
		return tick >= int(condition.get("tick", 0))
	if condition_type == "objective_completed":
		return _is_objective_completed(game_state, str(condition.get("objective_id", "")))
	if condition_type == "structure_count_at_least":
		return _count_structures(
			game_state,
			int(condition.get("owner_id", 1)),
			str(condition.get("structure_type", "")),
			true
		) >= int(condition.get("count", 1))
	if condition_type == "unit_count_at_least":
		return _count_units(
			game_state,
			int(condition.get("owner_id", 1)),
			str(condition.get("unit_role", "")),
			true
		) >= int(condition.get("count", 1))
	if condition_type == "destroy_structure_type":
		return _count_structures(
			game_state,
			int(condition.get("owner_id", 1)),
			str(condition.get("structure_type", "")),
			false
		) == 0
	if condition_type == "all_conditions":
		var conditions: Array[Dictionary] = _get_dict_array(condition.get("conditions", []))
		for subcondition in conditions:
			if not _is_condition_met(game_state, subcondition, tick):
				return false
		return true
	return false


func _is_objective_completed(game_state: GameState, objective_id: String) -> bool:
	for objective in _get_objectives(game_state):
		if str(objective.get("id", "")) != objective_id:
			continue
		return bool(objective.get("completed", false))
	return false


func _count_structures(game_state: GameState, owner_id: int, structure_type: String, require_constructed: bool) -> int:
	var count: int = 0
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var stockpile: Dictionary = game_state.get_entity_dict(entity_id)
		if structure_type == "stockpile" and game_state.get_entity_owner_id(stockpile) == owner_id:
			count += 1
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_structure_type(entity) != structure_type:
			continue
		if require_constructed and not game_state.get_entity_is_constructed(entity):
			continue
		count += 1
	return count


func _count_units(game_state: GameState, owner_id: int, unit_role: String, require_alive: bool) -> int:
	var count: int = 0
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) != owner_id:
			continue
		if game_state.get_entity_unit_role(entity) != unit_role:
			continue
		if require_alive and game_state.get_entity_hp(entity) <= 0:
			continue
		count += 1
	return count


func _find_stockpile_id(game_state: GameState, owner_id: int) -> int:
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_owner_id(entity) == owner_id:
			return entity_id
	return 0


func _append_alert(game_state: GameState, kind: String, text: String, tick: int) -> void:
	var alerts: Array[Dictionary] = _get_dict_array(game_state.scenario_state.get("alerts", []))
	alerts.append({
		"tick": tick,
		"kind": kind,
		"text": text,
	})
	while alerts.size() > 12:
		alerts.remove_at(0)
	game_state.scenario_state["alerts"] = alerts


func _get_objectives(game_state: GameState) -> Array[Dictionary]:
	return _get_dict_array(game_state.scenario_state.get("objectives", []))


func _get_events(game_state: GameState) -> Array[Dictionary]:
	return _get_dict_array(game_state.scenario_state.get("events", []))


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _get_dict_array(value: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not (value is Array):
		return items
	for item in value:
		if item is Dictionary:
			items.append(item.duplicate(true))
	return items


func _get_string_array(value: Variant) -> Array[String]:
	var items: Array[String] = []
	if not (value is Array):
		return items
	for item in value:
		if item is String:
			items.append(item)
	return items


func _get_vector2i_array(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not (value is Array):
		return cells
	for item in value:
		if item is Vector2i:
			cells.append(item)
	return cells
