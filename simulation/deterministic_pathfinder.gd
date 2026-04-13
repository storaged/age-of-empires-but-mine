class_name DeterministicPathfinder
extends RefCounted

## Deterministic 4-neighbor BFS.
## Neighbor order is fixed: right, left, down, up.

const INVALID_CELL: Vector2i = Vector2i(-1, -1)
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


## Finds a path from start_cell to target_cell using BFS.
## If avoid_occupied is true, treats cells currently occupied by other units as impassable,
## except for the target cell itself. Falls back cleanly to empty array if unreachable.
static func find_path(
	game_state: GameState,
	start_cell: Vector2i,
	target_cell: Vector2i,
	avoid_occupied: bool = false
) -> Array[Vector2i]:
	if start_cell == target_cell:
		return []

	if not game_state.is_cell_walkable(target_cell):
		return []

	var queue: Array[Vector2i] = []
	queue.append(start_cell)
	var queue_index: int = 0
	var visited: Dictionary = {game_state.cell_key(start_cell): true}
	var parents: Dictionary = {}

	while queue_index < queue.size():
		var current_cell_value: Variant = queue[queue_index]
		queue_index += 1
		if not (current_cell_value is Vector2i):
			continue
		var current_cell: Vector2i = current_cell_value

		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current_cell + offset
			if not game_state.is_cell_walkable(neighbor):
				continue
			if avoid_occupied and neighbor != target_cell and game_state.is_cell_occupied_by_unit(neighbor):
				continue

			var neighbor_key: String = game_state.cell_key(neighbor)
			if visited.has(neighbor_key):
				continue

			visited[neighbor_key] = true
			parents[neighbor_key] = current_cell

			if neighbor == target_cell:
				return _reconstruct_path(game_state, parents, start_cell, target_cell)

			queue.append(neighbor)

	return []


static func _reconstruct_path(
	game_state: GameState,
	parents: Dictionary,
	start_cell: Vector2i,
	target_cell: Vector2i
) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []
	var current_cell: Vector2i = target_cell

	while current_cell != start_cell:
		reversed_path.append(current_cell)
		var parent_cell_value: Variant = parents[game_state.cell_key(current_cell)]
		if not (parent_cell_value is Vector2i):
			return []
		var parent_cell: Vector2i = parent_cell_value
		current_cell = parent_cell

	reversed_path.reverse()
	return reversed_path


static func find_path_to_adjacent_target(
	game_state: GameState,
	start_cell: Vector2i,
	target_cell: Vector2i
) -> Array[Vector2i]:
	var adjacent_cells: Array[Vector2i] = game_state.get_adjacent_walkable_cells(target_cell)
	var best_path: Array[Vector2i] = []
	var best_path_found: bool = false

	for adjacent_cell in adjacent_cells:
		var candidate_path: Array[Vector2i] = find_path(game_state, start_cell, adjacent_cell)
		var candidate_is_valid: bool = adjacent_cell == start_cell or not candidate_path.is_empty()
		if not candidate_is_valid:
			continue

		if not best_path_found:
			best_path = candidate_path
			best_path_found = true
			continue

		if candidate_path.size() < best_path.size():
			best_path = candidate_path

	return best_path


static func find_nearest_valid_unit_spawn_cell(
	game_state: GameState,
	requested_cell: Vector2i
) -> Vector2i:
	return _find_nearest_valid_cell(
		game_state,
		requested_cell,
		func(candidate_cell: Vector2i) -> bool:
			return game_state.is_cell_valid_for_unit_spawn(candidate_cell)
	)


static func find_nearest_valid_structure_cell(
	game_state: GameState,
	requested_cell: Vector2i
) -> Vector2i:
	return _find_nearest_valid_cell(
		game_state,
		requested_cell,
		func(candidate_cell: Vector2i) -> bool:
			return game_state.is_cell_valid_for_structure_spawn(candidate_cell)
	)


static func _find_nearest_valid_cell(
	game_state: GameState,
	requested_cell: Vector2i,
	validator: Callable
) -> Vector2i:
	var best_cell: Vector2i = INVALID_CELL
	var best_distance: int = 999999
	for y in range(game_state.get_map_height()):
		for x in range(game_state.get_map_width()):
			var candidate_cell: Vector2i = Vector2i(x, y)
			if not validator.call(candidate_cell):
				continue
			var distance: int = absi(candidate_cell.x - requested_cell.x) + absi(candidate_cell.y - requested_cell.y)
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate_cell
				continue
			if distance == best_distance:
				if candidate_cell.y < best_cell.y:
					best_cell = candidate_cell
				elif candidate_cell.y == best_cell.y and candidate_cell.x < best_cell.x:
					best_cell = candidate_cell
	return best_cell
