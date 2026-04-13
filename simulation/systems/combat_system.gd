class_name CombatSystem
extends SimulationSystem

const AttackCommandClass = preload("res://commands/attack_command.gd")
const AttackMoveCommandClass = preload("res://commands/attack_move_command.gd")
const DeterministicPathfinderClass = preload("res://simulation/deterministic_pathfinder.gd")
const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const TASK_REVALIDATE_WAIT_TICKS: int = 6


func apply(game_state: GameState, commands_for_tick: Array[SimulationCommand], _tick: int) -> void:
	for command in commands_for_tick:
		if command.command_type == "attack":
			_apply_attack_command(game_state, command)
		elif command.command_type == "attack_move":
			_apply_attack_move_command(game_state, command)

	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if not game_state.get_entity_can_attack(entity):
			continue
		var task: String = game_state.get_entity_task_state(entity)
		if task == "attack_moving":
			_update_attack_moving(game_state, entity_id, entity)
			continue
		var target_id: int = game_state.get_entity_attack_target_id(entity)
		if target_id == 0:
			continue
		_update_attacking_unit(game_state, entity_id, entity)


func _apply_attack_move_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is AttackMoveCommandClass):
		return
	var amc: AttackMoveCommandClass = command
	if not game_state.entities.has(amc.unit_id):
		return
	var attacker: Dictionary = game_state.get_entity_dict(amc.unit_id)
	if not game_state.get_entity_can_attack(attacker):
		return
	if not game_state.is_cell_walkable(amc.target_cell):
		return

	var attacker_cell: Vector2i = game_state.get_entity_grid_position(attacker)
	var path: Array[Vector2i] = _find_path_avoid_occupied(game_state, attacker_cell, amc.target_cell)
	attacker["worker_task_state"] = "attack_moving"
	attacker["attack_move_target_cell"] = amc.target_cell
	attacker["attack_target_id"] = 0
	attacker["attack_cooldown_remaining"] = 0
	attacker["path_cells"] = path
	attacker["has_move_target"] = not path.is_empty()
	attacker["move_target"] = amc.target_cell
	attacker["interaction_slot_cell"] = Vector2i(-1, -1)
	game_state.entities[amc.unit_id] = attacker


## Advances an attack-moving unit: scan for in-range enemies each tick; acquire if found.
## When no enemy nearby, keep following path toward destination.
func _update_attack_moving(game_state: GameState, entity_id: int, attacker: Dictionary) -> void:
	var dest: Vector2i = Vector2i(-1, -1)
	if attacker.has("attack_move_target_cell") and attacker["attack_move_target_cell"] is Vector2i:
		dest = attacker["attack_move_target_cell"]
	if dest == Vector2i(-1, -1):
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return

	var attacker_cell: Vector2i = game_state.get_entity_grid_position(attacker)

	# Scan for enemies within attack range — O(entities), deterministic (sorted ids).
	var nearest_enemy_id: int = _find_nearest_enemy_in_attack_range(game_state, attacker)
	if nearest_enemy_id != 0:
		var target_entity: Dictionary = game_state.get_entity_dict(nearest_enemy_id)
		if game_state.get_entity_hp(target_entity) > 0:
			attacker["attack_target_id"] = nearest_enemy_id
			attacker["attack_cooldown_remaining"] = 0
			_assign_attack_path(game_state, entity_id, attacker, nearest_enemy_id)
			return

	# Arrived at destination.
	if attacker_cell == dest:
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return

	if _attacker_requires_revalidation(game_state, attacker):
		var path: Array[Vector2i] = _find_path_avoid_occupied(game_state, attacker_cell, dest)
		if path.is_empty():
			_set_attacker_idle(attacker)
			game_state.entities[entity_id] = attacker
			return
		attacker["path_cells"] = path
		attacker["has_move_target"] = true
		attacker["move_target"] = dest
		game_state.entities[entity_id] = attacker


## Returns the nearest damageable enemy entity id within the attacker's attack range.
## Deterministic: iterates sorted entity ids, tie-breaks by id (lower wins).
func _find_nearest_enemy_in_attack_range(game_state: GameState, attacker: Dictionary) -> int:
	var attacker_cell: Vector2i = game_state.get_entity_grid_position(attacker)
	var owner_id: int = game_state.get_entity_owner_id(attacker)
	var attack_range: int = maxi(game_state.get_entity_attack_range_cells(attacker), 1)

	var nearest_id: int = 0
	var nearest_dist: int = attack_range + 1

	var sorted_ids: Array = game_state.entities.keys()
	sorted_ids.sort()
	for entity_id in sorted_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var entity_owner: int = game_state.get_entity_owner_id(entity)
		if entity_owner == 0 or entity_owner == owner_id:
			continue
		if not game_state.get_entity_is_damageable(entity):
			continue
		if game_state.get_entity_hp(entity) <= 0:
			continue
		var entity_cell: Vector2i = game_state.get_entity_grid_position(entity)
		var dist: int = _manhattan_distance(attacker_cell, entity_cell)
		if dist > attack_range:
			continue
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = entity_id

	return nearest_id


func _apply_attack_command(game_state: GameState, command: SimulationCommand) -> void:
	if not (command is AttackCommandClass):
		return

	var attack_command: AttackCommandClass = command
	if not game_state.entities.has(attack_command.unit_id):
		return
	if not game_state.entities.has(attack_command.target_id):
		return

	var attacker: Dictionary = game_state.get_entity_dict(attack_command.unit_id)
	if not game_state.get_entity_can_attack(attacker):
		return

	var target: Dictionary = game_state.get_entity_dict(attack_command.target_id)
	if not game_state.get_entity_is_damageable(target):
		return
	if game_state.get_entity_hp(target) <= 0:
		return

	attacker["attack_target_id"] = attack_command.target_id
	attacker["attack_cooldown_remaining"] = 0
	_assign_attack_path(game_state, attack_command.unit_id, attacker, attack_command.target_id)


func _update_attacking_unit(game_state: GameState, entity_id: int, attacker: Dictionary) -> void:
	var target_id: int = game_state.get_entity_attack_target_id(attacker)
	var task: String = game_state.get_entity_task_state(attacker)

	# Stale target_id from a previous attack interrupted by a move command
	if task != "to_target" and task != "attacking":
		attacker["attack_target_id"] = 0
		game_state.entities[entity_id] = attacker
		return

	if not game_state.entities.has(target_id):
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return

	var target: Dictionary = game_state.get_entity_dict(target_id)
	if not game_state.get_entity_is_damageable(target):
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return
	if game_state.get_entity_hp(target) <= 0:
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return

	var attacker_cell: Vector2i = game_state.get_entity_grid_position(attacker)
	var target_cell: Vector2i = game_state.get_entity_grid_position(target)
	var attack_range: int = maxi(game_state.get_entity_attack_range_cells(attacker), 1)
	var distance_to_target: int = _manhattan_distance(attacker_cell, target_cell)
	var in_attack_range: bool = distance_to_target <= attack_range and attacker_cell != target_cell
	var interaction_slot: Vector2i = game_state.get_entity_interaction_slot_cell(attacker)

	if task == "to_target":
		if _attacker_requires_revalidation(game_state, attacker) or _attack_slot_invalid(
			game_state,
			attacker_cell,
			interaction_slot,
			target_cell,
			attack_range
		):
			_assign_attack_path(game_state, entity_id, attacker, target_id)
			return
		if in_attack_range and (interaction_slot == Vector2i(-1, -1) or attacker_cell == interaction_slot):
			attacker["worker_task_state"] = "attacking"
			attacker["attack_cooldown_remaining"] = 0
			attacker["path_cells"] = []
			attacker["has_move_target"] = false
			attacker["move_target"] = attacker_cell
			game_state.entities[entity_id] = attacker
		elif game_state.get_entity_path_cells(attacker).is_empty():
			_assign_attack_path(game_state, entity_id, attacker, target_id)
		return

	# task == "attacking"
	if not in_attack_range:
		attacker["worker_task_state"] = "to_target"
		_assign_attack_path(game_state, entity_id, attacker, target_id)
		return
	if _attacker_requires_revalidation(game_state, attacker):
		attacker["worker_task_state"] = "to_target"
		_assign_attack_path(game_state, entity_id, attacker, target_id)
		return

	if interaction_slot != Vector2i(-1, -1):
		attacker["interaction_slot_cell"] = attacker_cell

	var cooldown: int = game_state.get_entity_attack_cooldown_remaining(attacker)
	if cooldown > 0:
		attacker["attack_cooldown_remaining"] = cooldown - 1
		game_state.entities[entity_id] = attacker
		return

	var base_damage: int = game_state.get_entity_int(attacker, "attack_damage", 5)
	var attacker_role: String = game_state.get_entity_unit_role(attacker)
	var target_role: String = game_state.get_entity_unit_role(target)
	var multiplier: int = GameDefinitionsClass.get_damage_multiplier(attacker_role, target_role)
	var damage: int = (base_damage * multiplier) / 100
	var current_hp: int = game_state.get_entity_hp(target)
	var new_hp: int = maxi(current_hp - damage, 0)
	target["hp"] = new_hp
	attacker["attack_cooldown_remaining"] = maxi(game_state.get_entity_int(attacker, "attack_cooldown_ticks", 4), 1)
	game_state.entities[entity_id] = attacker

	if new_hp <= 0:
		_kill_entity(game_state, target_id, target)
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
	else:
		game_state.entities[target_id] = target


func _assign_attack_path(
	game_state: GameState,
	entity_id: int,
	attacker: Dictionary,
	target_id: int
) -> void:
	var target: Dictionary = game_state.get_entity_dict(target_id)
	var target_cell: Vector2i = game_state.get_entity_grid_position(target)
	var attacker_cell: Vector2i = game_state.get_entity_grid_position(attacker)
	var attack_range: int = maxi(game_state.get_entity_attack_range_cells(attacker), 1)

	if _is_cell_in_attack_range(attacker_cell, target_cell, attack_range):
		attacker["interaction_slot_cell"] = attacker_cell
		attacker["path_cells"] = []
		attacker["has_move_target"] = false
		attacker["move_target"] = attacker_cell
		attacker["worker_task_state"] = "attacking"
		game_state.entities[entity_id] = attacker
		return

	var slot_cell: Vector2i = _find_attack_position(
		game_state,
		target_id,
		entity_id,
		target_cell,
		attacker_cell,
		attack_range
	)
	if slot_cell == Vector2i(-1, -1):
		_set_attacker_idle(attacker)
		game_state.entities[entity_id] = attacker
		return

	var path: Array[Vector2i] = _find_path_avoid_occupied(game_state, attacker_cell, slot_cell)
	attacker["interaction_slot_cell"] = slot_cell
	attacker["path_cells"] = path
	attacker["has_move_target"] = not path.is_empty()
	attacker["move_target"] = slot_cell
	attacker["worker_task_state"] = "to_target"
	game_state.entities[entity_id] = attacker


func _find_attack_position(
	game_state: GameState,
	target_id: int,
	attacker_id: int,
	target_cell: Vector2i,
	attacker_cell: Vector2i,
	attack_range: int
) -> Vector2i:
	var candidate_cells: Array[Vector2i] = _build_attack_candidate_cells(game_state, target_cell, attack_range)
	if candidate_cells.is_empty():
		return Vector2i(-1, -1)

	var attacker_ids: Array[int] = _get_attacker_ids_for_target(game_state, target_id, attacker_id)
	var claimed_cells: Array[Vector2i] = []
	for next_attacker_id in attacker_ids:
		var next_attacker: Dictionary = game_state.get_entity_dict(next_attacker_id)
		var next_attacker_cell: Vector2i = game_state.get_entity_grid_position(next_attacker)
		var best_cell: Vector2i = _find_best_attack_cell(
			game_state,
			candidate_cells,
			claimed_cells,
			next_attacker_cell
		)
		if next_attacker_id == attacker_id:
			return best_cell
		if best_cell != Vector2i(-1, -1):
			claimed_cells.append(best_cell)
	return Vector2i(-1, -1)


func _get_attacker_ids_for_target(game_state: GameState, target_id: int, attacker_id: int) -> Array[int]:
	var attacker_ids: Array[int] = []
	for entity_id in game_state.get_entities_by_type("unit"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if not game_state.get_entity_can_attack(entity):
			continue
		if game_state.get_entity_attack_target_id(entity) != target_id:
			continue
		var task_state: String = game_state.get_entity_task_state(entity)
		if task_state != "to_target" and task_state != "attacking":
			continue
		attacker_ids.append(entity_id)
	if not attacker_ids.has(attacker_id):
		attacker_ids.append(attacker_id)
	attacker_ids.sort()
	return attacker_ids


func _find_best_attack_cell(
	game_state: GameState,
	candidate_cells: Array[Vector2i],
	claimed_cells: Array[Vector2i],
	attacker_cell: Vector2i
) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_path_length: int = 999999
	for candidate_cell in candidate_cells:
		if claimed_cells.has(candidate_cell):
			continue
		var path: Array[Vector2i] = _find_path_avoid_occupied(game_state, attacker_cell, candidate_cell)
		if path.is_empty() and attacker_cell != candidate_cell:
			continue
		var path_length: int = path.size()
		if best_cell == Vector2i(-1, -1) or path_length < best_path_length:
			best_cell = candidate_cell
			best_path_length = path_length
		elif path_length == best_path_length and _is_cell_before(candidate_cell, best_cell, attacker_cell):
			best_cell = candidate_cell
	if best_cell != Vector2i(-1, -1):
		return best_cell
	for candidate_cell in candidate_cells:
		if claimed_cells.has(candidate_cell):
			continue
		var fallback_path: Array[Vector2i] = DeterministicPathfinderClass.find_path(
			game_state, attacker_cell, candidate_cell, false
		)
		if fallback_path.is_empty() and attacker_cell != candidate_cell:
			continue
		var fallback_length: int = fallback_path.size()
		if best_cell == Vector2i(-1, -1) or fallback_length < best_path_length:
			best_cell = candidate_cell
			best_path_length = fallback_length
		elif fallback_length == best_path_length and _is_cell_before(candidate_cell, best_cell, attacker_cell):
			best_cell = candidate_cell
	return best_cell


func _build_attack_candidate_cells(
	game_state: GameState,
	target_cell: Vector2i,
	attack_range: int
) -> Array[Vector2i]:
	var candidate_cells: Array[Vector2i] = []
	for dy in range(-attack_range, attack_range + 1):
		for dx in range(-attack_range, attack_range + 1):
			var candidate_cell: Vector2i = target_cell + Vector2i(dx, dy)
			if candidate_cell == target_cell:
				continue
			if not game_state.is_cell_walkable(candidate_cell):
				continue
			var candidate_distance: int = _manhattan_distance(candidate_cell, target_cell)
			if candidate_distance <= 0 or candidate_distance > attack_range:
				continue
			candidate_cells.append(candidate_cell)

	candidate_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a: int = _manhattan_distance(a, target_cell)
		var dist_b: int = _manhattan_distance(b, target_cell)
		if dist_a != dist_b:
			return dist_a < dist_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return candidate_cells


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
	if entity_type == "stockpile" or entity_type == "structure" or entity_type == "resource_node":
		game_state.rebuild_static_blocker_cache()


func _set_attacker_idle(attacker: Dictionary) -> void:
	var cell: Vector2i = Vector2i.ZERO
	if attacker.has("grid_position") and attacker["grid_position"] is Vector2i:
		cell = attacker["grid_position"]
	attacker["attack_target_id"] = 0
	attacker["attack_cooldown_remaining"] = 0
	attacker["path_cells"] = []
	attacker["has_move_target"] = false
	attacker["interaction_slot_cell"] = Vector2i(-1, -1)
	attacker["movement_wait_ticks"] = 0
	attacker["traffic_state"] = ""

	# Resume attack-move toward destination if one is still active.
	var attack_move_dest: Vector2i = Vector2i(-1, -1)
	if attacker.has("attack_move_target_cell") and attacker["attack_move_target_cell"] is Vector2i:
		attack_move_dest = attacker["attack_move_target_cell"]
	if attack_move_dest != Vector2i(-1, -1) and attack_move_dest != cell:
		attacker["worker_task_state"] = "attack_moving"
		attacker["move_target"] = attack_move_dest
	else:
		attacker["worker_task_state"] = "idle"
		attacker["move_target"] = cell
		attacker["attack_move_target_cell"] = Vector2i(-1, -1)


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


func _manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)


func _is_cell_in_attack_range(from_cell: Vector2i, target_cell: Vector2i, attack_range: int) -> bool:
	return from_cell != target_cell and _manhattan_distance(from_cell, target_cell) <= attack_range


func _is_cell_before(left: Vector2i, right: Vector2i, attacker_cell: Vector2i) -> bool:
	var left_dist: int = _manhattan_distance(left, attacker_cell)
	var right_dist: int = _manhattan_distance(right, attacker_cell)
	if left_dist != right_dist:
		return left_dist < right_dist
	if left.y != right.y:
		return left.y < right.y
	return left.x < right.x


func _attacker_requires_revalidation(game_state: GameState, attacker: Dictionary) -> bool:
	var traffic_state: String = game_state.get_entity_string(attacker, "traffic_state", "")
	if traffic_state == "stale_intent":
		return true
	return game_state.get_entity_movement_wait_ticks(attacker) >= TASK_REVALIDATE_WAIT_TICKS


func _attack_slot_invalid(
	game_state: GameState,
	attacker_cell: Vector2i,
	slot_cell: Vector2i,
	target_cell: Vector2i,
	attack_range: int
) -> bool:
	if slot_cell == Vector2i(-1, -1):
		return true
	if attacker_cell == slot_cell:
		return not _is_cell_in_attack_range(attacker_cell, target_cell, attack_range)
	if not _is_cell_in_attack_range(slot_cell, target_cell, attack_range):
		return true
	return not game_state.is_cell_walkable(slot_cell)
