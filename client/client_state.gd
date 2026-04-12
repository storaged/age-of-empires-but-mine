class_name ClientState
extends RefCounted

## Presentation-only client state.

var camera_world_position: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
var selected_entity_ids: Array[int] = []
var hover_cell: Vector2i = Vector2i(-1, -1)
var hovered_entity_id: int = -1
var indicators: Array[Dictionary] = []
var last_order_feedback: String = ""
var last_order_was_rejected: bool = false
var placement_mode_structure_type: String = ""
var placement_preview_cell: Vector2i = Vector2i(-1, -1)
var placement_preview_valid: bool = false
var placement_preview_reason: String = ""
var is_drag_selecting: bool = false
var drag_select_start_world: Vector2 = Vector2.ZERO
var drag_select_current_world: Vector2 = Vector2.ZERO
var visual_unit_start_positions: Dictionary = {}
var visual_unit_target_positions: Dictionary = {}
var visual_unit_world_positions: Dictionary = {}


func set_camera_world_position(world_position: Vector2) -> void:
	camera_world_position = world_position


func set_camera_zoom(next_zoom: float) -> void:
	camera_zoom = next_zoom


func set_hover_cell(cell: Vector2i) -> void:
	hover_cell = cell


func set_hovered_entity_id(entity_id: int) -> void:
	hovered_entity_id = entity_id


func set_selection(entity_ids: Array[int]) -> void:
	selected_entity_ids.clear()
	for entity_id in entity_ids:
		selected_entity_ids.append(entity_id)
	selected_entity_ids.sort()


func clear_selection() -> void:
	selected_entity_ids.clear()


func begin_structure_placement(structure_type: String) -> void:
	placement_mode_structure_type = structure_type


func cancel_structure_placement() -> void:
	placement_mode_structure_type = ""
	placement_preview_cell = Vector2i(-1, -1)
	placement_preview_valid = false
	placement_preview_reason = ""


func is_in_structure_placement_mode() -> bool:
	return placement_mode_structure_type != ""


func set_placement_preview(cell: Vector2i, is_valid: bool, reason: String) -> void:
	placement_preview_cell = cell
	placement_preview_valid = is_valid
	placement_preview_reason = reason


func add_indicator(indicator: Dictionary) -> void:
	indicators.append(indicator)


func set_move_indicator(cell: Vector2i) -> void:
	indicators.clear()
	indicators.append({
		"type": "move_target",
		"cell": cell,
	})


func set_move_indicators(cells: Array[Vector2i]) -> void:
	indicators.clear()
	for cell in cells:
		indicators.append({
			"type": "move_target",
			"cell": cell,
		})


func set_gather_indicator(cell: Vector2i) -> void:
	indicators.clear()
	indicators.append({
		"type": "gather_target",
		"cell": cell,
	})


func set_return_indicator(cell: Vector2i) -> void:
	indicators.clear()
	indicators.append({
		"type": "return_target",
		"cell": cell,
	})


func set_invalid_indicator(cell: Vector2i, message: String) -> void:
	indicators.clear()
	indicators.append({
		"type": "invalid_target",
		"cell": cell,
	})
	last_order_feedback = message
	last_order_was_rejected = true


func set_build_indicator(cell: Vector2i) -> void:
	indicators.clear()
	indicators.append({
		"type": "build_target",
		"cell": cell,
	})


func set_order_feedback(message: String, was_rejected: bool) -> void:
	last_order_feedback = message
	last_order_was_rejected = was_rejected


func clear_indicators() -> void:
	indicators.clear()


func sync_visual_unit_target(unit_id: int, authoritative_world_position: Vector2) -> void:
	var previous_visual_position: Vector2 = get_visual_unit_world_position(
		unit_id,
		authoritative_world_position
	)

	visual_unit_start_positions[unit_id] = previous_visual_position
	visual_unit_target_positions[unit_id] = authoritative_world_position

	if not visual_unit_world_positions.has(unit_id):
		visual_unit_world_positions[unit_id] = authoritative_world_position


func update_visual_interpolation(alpha: float) -> void:
	var unit_ids: Array = visual_unit_target_positions.keys()
	unit_ids.sort()

	for unit_id in unit_ids:
		var start_position: Vector2 = _get_stored_vector2(
			visual_unit_start_positions,
			unit_id,
			Vector2.ZERO
		)
		var target_position: Vector2 = _get_stored_vector2(
			visual_unit_target_positions,
			unit_id,
			Vector2.ZERO
		)
		visual_unit_world_positions[unit_id] = start_position.lerp(target_position, alpha)


func remove_missing_visual_units(valid_unit_ids: Array[int]) -> void:
	var valid_lookup: Dictionary = {}
	for unit_id in valid_unit_ids:
		valid_lookup[unit_id] = true

	for unit_id in visual_unit_world_positions.keys():
		if valid_lookup.has(unit_id):
			continue

		visual_unit_world_positions.erase(unit_id)
		visual_unit_start_positions.erase(unit_id)
		visual_unit_target_positions.erase(unit_id)


func get_visual_unit_world_position(unit_id: int, fallback: Vector2) -> Vector2:
	return _get_stored_vector2(visual_unit_world_positions, unit_id, fallback)


func begin_drag_selection(world_position: Vector2) -> void:
	is_drag_selecting = true
	drag_select_start_world = world_position
	drag_select_current_world = world_position


func update_drag_selection(world_position: Vector2) -> void:
	drag_select_current_world = world_position


func end_drag_selection() -> void:
	is_drag_selecting = false


func get_drag_world_rect() -> Rect2:
	var top_left: Vector2 = Vector2(
		minf(drag_select_start_world.x, drag_select_current_world.x),
		minf(drag_select_start_world.y, drag_select_current_world.y)
	)
	var bottom_right: Vector2 = Vector2(
		maxf(drag_select_start_world.x, drag_select_current_world.x),
		maxf(drag_select_start_world.y, drag_select_current_world.y)
	)
	return Rect2(top_left, bottom_right - top_left)


func _get_stored_vector2(storage: Dictionary, key: Variant, fallback: Vector2) -> Vector2:
	if not storage.has(key):
		return fallback

	var value: Variant = storage[key]
	if value is Vector2:
		return value

	return fallback
