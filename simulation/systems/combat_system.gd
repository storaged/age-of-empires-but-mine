class_name CombatSystem
extends SimulationSystem

const AttackCommandClass = preload("res://commands/attack_command.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type == "attack":
			_apply_attack_command(game_state, command)

	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if not game_state.get_entity_can_attack(entity):
			continue
		var target_id: int = game_state.get_entity_attack_target_id(entity)
		if target_id == 0:
			continue
		_update_attacking_soldier(game_state, entity_id, entity)


func _apply_attack_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is AttackCommandClass):
		return

	var attack_command: AttackCommandClass = command
	if not game_state.entities.has(attack_command.unit_id):
		return
	if not game_state.entities.has(attack_command.target_id):
		return

	var soldier: Dictionary = game_state.get_entity_dict(attack_command.unit_id)
	if not game_state.get_entity_can_attack(soldier):
		return

	var target: Dictionary = game_state.get_entity_dict(attack_command.target_id)
	if game_state.get_entity_hp(target) <= 0:
		return

	soldier["attack_target_id"] = attack_command.target_id
	soldier["attack_cooldown_remaining"] = 0
	_assign_attack_path(game_state, attack_command.unit_id, soldier, attack_command.target_id)
	game_state.entities[attack_command.unit_id] = soldier


func _update_attacking_soldier(game_state: GameState, entity_id: int, soldier: Dictionary) -> void:
	var target_id: int = game_state.get_entity_attack_target_id(soldier)
	var task: String = game_state.get_entity_task_state(soldier)

	# Stale target_id from a previous attack interrupted by a move command
	if task != "to_target" and task != "attacking":
		soldier["attack_target_id"] = 0
		game_state.entities[entity_id] = soldier
		return

	if not game_state.entities.has(target_id):
		_set_soldier_idle(soldier)
		game_state.entities[entity_id] = soldier
		return

	var target: Dictionary = game_state.get_entity_dict(target_id)
	if game_state.get_entity_hp(target) <= 0:
		_set_soldier_idle(soldier)
		game_state.entities[entity_id] = soldier
		return

	var soldier_cell: Vector2i = game_state.get_entity_grid_position(soldier)
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(soldier)

	if task == "to_target":
		if soldier_cell == interaction_slot:
			soldier["worker_task_state"] = "attacking"
			soldier["attack_cooldown_remaining"] = 0
			soldier["path_cells"] = []
			soldier["has_move_target"] = false
			soldier["move_target"] = soldier_cell
			game_state.entities[entity_id] = soldier
		elif game_state.get_entity_path_cells(soldier).is_empty():
			_assign_attack_path(game_state, entity_id, soldier, target_id)
		return

	# task == "attacking"
	if soldier_cell != interaction_slot:
		soldier["worker_task_state"] = "to_target"
		_assign_attack_path(game_state, entity_id, soldier, target_id)
		return

	var cooldown: int = game_state.get_entity_attack_cooldown_remaining(soldier)
	if cooldown > 0:
		soldier["attack_cooldown_remaining"] = cooldown - 1
		game_state.entities[entity_id] = soldier
		return

	var damage: int = game_state.get_entity_int(soldier, "attack_damage", 5)
	var current_hp: int = game_state.get_entity_hp(target)
	var new_hp: int = maxi(current_hp - damage, 0)
	target["hp"] = new_hp
	soldier["attack_cooldown_remaining"] = maxi(game_state.get_entity_int(soldier, "attack_cooldown_ticks", 4), 1)
	game_state.entities[entity_id] = soldier

	if new_hp <= 0:
		_kill_entity(game_state, target_id, target)
		_set_soldier_idle(soldier)
		game_state.entities[entity_id] = soldier
	else:
		game_state.entities[target_id] = target


func _assign_attack_path(
	game_state: GameState,
	entity_id: int,
	soldier: Dictionary,
	target_id: int
) -> void:
	var target: Dictionary = game_state.get_entity_dict(target_id)
	var target_cell: Vector2i = game_state.get_entity_grid_position(target)
	var soldier_cell: Vector2i = game_state.get_entity_grid_position(soldier)

	var slot_cell: Vector2i = _find_attack_slot(game_state, target_cell, soldier_cell)
	if slot_cell == Vector2i(-1, -1):
		_set_soldier_idle(soldier)
		return

	var path: Array[Vector2i] = _find_path_avoid_occupied(game_state, soldier_cell, slot_cell)
	soldier["interaction_slot_cell"] = slot_cell
	soldier["path_cells"] = path
	soldier["has_move_target"] = not path.is_empty()
	soldier["move_target"] = slot_cell
	soldier["worker_task_state"] = "to_target"
	game_state.entities[entity_id] = soldier


func _find_attack_slot(
	game_state: GameState,
	target_cell: Vector2i,
	soldier_cell: Vector2i
) -> Vector2i:
	var adjacent: Array[Vector2i] = game_state.get_adjacent_walkable_cells(target_cell)
	if adjacent.is_empty():
		return Vector2i(-1, -1)

	# Prefer unoccupied slots so we don't try to walk into an occupied cell
	var unoccupied: Array[Vector2i] = []
	for cell in adjacent:
		if not game_state.is_cell_occupied_by_unit(cell):
			unoccupied.append(cell)
	var candidates: Array[Vector2i] = unoccupied if not unoccupied.is_empty() else adjacent

	var best_cell: Vector2i = candidates[0]
	var best_dist: int = absi(best_cell.x - soldier_cell.x) + absi(best_cell.y - soldier_cell.y)
	for i in range(1, candidates.size()):
		var cell: Vector2i = candidates[i]
		var dist: int = absi(cell.x - soldier_cell.x) + absi(cell.y - soldier_cell.y)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
		elif dist == best_dist and (cell.y < best_cell.y or (cell.y == best_cell.y and cell.x < best_cell.x)):
			best_cell = cell
	return best_cell


func _kill_entity(game_state: GameState, entity_id: int, entity: Dictionary) -> void:
	var entity_type: String = game_state.get_entity_type(entity)
	var owner_id: int = game_state.get_entity_owner_id(entity)
	if entity_type == "stockpile" and owner_id == 1:
		game_state.lose_condition_met = true
	if entity_type == "structure" and owner_id == 2 and game_state.get_entity_structure_type(entity) == "enemy_base":
		game_state.win_condition_met = true
	if entity_type == "unit":
		var cell: Vector2i = game_state.get_entity_grid_position(entity)
		game_state.occupancy.erase(game_state.cell_key(cell))
	game_state.entities.erase(entity_id)


func _set_soldier_idle(soldier: Dictionary) -> void:
	var cell: Vector2i = Vector2i.ZERO
	if soldier.has("grid_position") and soldier["grid_position"] is Vector2i:
		cell = soldier["grid_position"]
	soldier["worker_task_state"] = "idle"
	soldier["attack_target_id"] = 0
	soldier["attack_cooldown_remaining"] = 0
	soldier["path_cells"] = []
	soldier["has_move_target"] = false
	soldier["move_target"] = cell
	soldier["interaction_slot_cell"] = Vector2i(-1, -1)


func _find_path_avoid_occupied(
	game_state: GameState,
	from_cell: Vector2i,
	to_cell: Vector2i
) -> Array[Vector2i]:
	var path: Array[Vector2i] = DeterministicPathfinderClass.find_path(
		game_state, from_cell, to_cell, true
	)
	if not path.is_empty() or from_cell == to_cell:
		return path
	return DeterministicPathfinderClass.find_path(game_state, from_cell, to_cell, false)
