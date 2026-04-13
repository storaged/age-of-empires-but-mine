class_name Visibility
extends RefCounted

## Authoritative visibility queries.
## Pure read-side — no GameState mutation.
## Called on demand (UI refresh, tests), never per-tick.
##
## Vision model: Manhattan distance.
## Each unit/structure has a vision_radius_cells from definitions.
## All cells within that radius from the entity's grid_position are visible.
##
## Future extension points:
##   - "last seen" state (store in GameState, updated by a VisionSystem)
##   - line-of-sight blocking (check blocked cells along ray)
##   - shroud rendering (pass visible dict to renderer)


## Returns a Dictionary mapping cell_key → true for every cell currently visible
## by any entity owned by owner_id. O(owned_entities × radius²).
static func compute_visible_cells(game_state: GameState, owner_id: int) -> Dictionary:
	var visible: Dictionary = {}
	var map_width: int = game_state.get_map_width()
	var map_height: int = game_state.get_map_height()
	for entity_id in game_state.entities.keys():
		var entity_value: Variant = game_state.entities[entity_id]
		if not (entity_value is Dictionary):
			continue
		var entity: Dictionary = entity_value
		var owner_value: Variant = entity.get("owner_id", 0)
		if not (owner_value is int) or owner_value != owner_id:
			continue
		var pos_value: Variant = entity.get("grid_position", null)
		if not (pos_value is Vector2i):
			continue
		var cell: Vector2i = pos_value
		var radius_value: Variant = entity.get("vision_radius_cells", 0)
		var radius: int = radius_value if radius_value is int else 0
		if radius <= 0:
			continue
		_mark_visible_in_radius(visible, cell, radius, map_width, map_height)
	return visible


## Returns true if the entity at entity_id is within any vision radius of observer_id.
static func is_entity_visible_to(
	game_state: GameState,
	entity_id: int,
	observer_id: int
) -> bool:
	if not game_state.entities.has(entity_id):
		return false
	var entity_value: Variant = game_state.entities[entity_id]
	if not (entity_value is Dictionary):
		return false
	var entity: Dictionary = entity_value
	var pos_value: Variant = entity.get("grid_position", null)
	if not (pos_value is Vector2i):
		return false
	var visible: Dictionary = compute_visible_cells(game_state, observer_id)
	return visible.has(_cell_key(pos_value))


## Count of enemy units (any owner != observer_id) currently visible to observer_id.
static func count_visible_enemy_units(game_state: GameState, observer_id: int) -> int:
	var visible: Dictionary = compute_visible_cells(game_state, observer_id)
	var count: int = 0
	for entity_id in game_state.entities.keys():
		var entity_value: Variant = game_state.entities[entity_id]
		if not (entity_value is Dictionary):
			continue
		var entity: Dictionary = entity_value
		var owner_value: Variant = entity.get("owner_id", 0)
		if not (owner_value is int) or owner_value == observer_id:
			continue
		var type_value: Variant = entity.get("entity_type", "")
		if not (type_value is String) or type_value != "unit":
			continue
		var pos_value: Variant = entity.get("grid_position", null)
		if not (pos_value is Vector2i):
			continue
		if visible.has(_cell_key(pos_value)):
			count += 1
	return count


## Count of cells visible to observer_id. Useful for coverage metrics and tests.
static func count_visible_cells(game_state: GameState, observer_id: int) -> int:
	return compute_visible_cells(game_state, observer_id).size()


static func _mark_visible_in_radius(
	visible: Dictionary,
	center: Vector2i,
	radius: int,
	map_width: int,
	map_height: int
) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if absi(dx) + absi(dy) > radius:
				continue
			var cx: int = center.x + dx
			var cy: int = center.y + dy
			if cx < 0 or cy < 0 or cx >= map_width or cy >= map_height:
				continue
			visible[_cell_key(Vector2i(cx, cy))] = true


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
