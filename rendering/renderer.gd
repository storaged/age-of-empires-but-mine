class_name GameRenderer
extends Node2D

## Rendering reads authoritative state and client state only.

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")

var game_state: GameState
var client_state: ClientState
var cell_size: int = 64

var grid_color: Color = Color("#3d4b4f")
var hover_color: Color = Color(0.36, 0.49, 0.53, 0.18)
var unit_color: Color = Color("#d6d2c4")
var soldier_color: Color = Color("#e63946")
var enemy_unit_color: Color = Color("#8b0000")
var selected_color: Color = Color("#ffd166")
var destination_color: Color = Color("#4ecdc4")
var attack_indicator_color: Color = Color("#e63946")
var authoritative_cell_color: Color = Color("#ff6b6b")
var obstacle_color: Color = Color("#6b705c")
var obstacle_edge_color: Color = Color("#a5a58d")
var invalid_color: Color = Color("#ef476f")
var resource_color: Color = Color("#5c8d3a")
var stone_color: Color = Color("#7a8b8f")
var archer_color: Color = Color("#2ec4b6")
var stockpile_color: Color = Color("#3a6ea5")
var gather_color: Color = Color("#9fd356")
var return_color: Color = Color("#7cc6fe")
var build_color: Color = Color("#f4a261")
var structure_color: Color = Color("#a56b3a")
var barracks_color: Color = Color("#4a4e69")
var archery_range_color: Color = Color("#1a6b5a")
var enemy_structure_color: Color = Color("#6b1a1a")


func configure(
	initial_game_state: GameState,
	initial_client_state: ClientState,
	initial_cell_size: int
) -> void:
	game_state = initial_game_state
	client_state = initial_client_state
	cell_size = initial_cell_size


func _draw() -> void:
	if game_state == null or client_state == null:
		return

	_draw_grid()
	_draw_obstacles()
	_draw_static_entities()
	_draw_hover_cell()
	_draw_placement_preview()
	_draw_drag_selection()
	_draw_destination_indicators()
	_draw_selected_paths()
	_draw_units()


func _draw_grid() -> void:
	var width: int = game_state.get_map_width()
	var height: int = game_state.get_map_height()
	var map_width_pixels: int = width * cell_size
	var map_height_pixels: int = height * cell_size

	draw_rect(
		Rect2(Vector2.ZERO, Vector2(map_width_pixels, map_height_pixels)),
		Color("#1a1f24"),
		true
	)

	for x in range(width + 1):
		var world_x: float = float(x * cell_size)
		draw_line(Vector2(world_x, 0.0), Vector2(world_x, map_height_pixels), grid_color, 1.0)

	for y in range(height + 1):
		var world_y: float = float(y * cell_size)
		draw_line(Vector2(0.0, world_y), Vector2(map_width_pixels, world_y), grid_color, 1.0)


func _draw_hover_cell() -> void:
	if client_state.hover_cell.x < 0 or client_state.hover_cell.y < 0:
		return

	var color: Color = hover_color
	if game_state.is_cell_blocked(client_state.hover_cell):
		color = Color(0.94, 0.28, 0.44, 0.18)
	draw_rect(_cell_rect(client_state.hover_cell), color, true)


func _draw_placement_preview() -> void:
	if not client_state.is_in_structure_placement_mode():
		return
	if client_state.placement_preview_cell.x < 0 or client_state.placement_preview_cell.y < 0:
		return

	var rect: Rect2 = _cell_rect(client_state.placement_preview_cell).grow(-4.0)
	var fill_color: Color = Color(0.96, 0.64, 0.38, 0.28)
	var outline_color: Color = build_color
	if not client_state.placement_preview_valid:
		fill_color = Color(0.94, 0.28, 0.44, 0.24)
		outline_color = invalid_color
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, 3.0)


func _draw_obstacles() -> void:
	var blocked_cells: Dictionary = game_state.get_blocked_cells()
	var keys: Array = blocked_cells.keys()
	keys.sort()

	for key in keys:
		var parts: PackedStringArray = String(key).split(",")
		var cell: Vector2i = Vector2i(parts[0].to_int(), parts[1].to_int())
		if _has_static_entity_at_cell(cell):
			continue
		var rect: Rect2 = _cell_rect(cell)
		draw_rect(rect, obstacle_color, true)
		draw_rect(rect.grow(-6.0), obstacle_edge_color, false, 2.0)


func _draw_destination_indicators() -> void:
	for indicator in client_state.indicators:
		var indicator_type: String = str(indicator.get("type", ""))
		if (
			indicator_type != "move_target"
			and indicator_type != "invalid_target"
			and indicator_type != "gather_target"
			and indicator_type != "return_target"
			and indicator_type != "build_target"
			and indicator_type != "attack_target"
		):
			continue

		var cell: Vector2i = Vector2i.ZERO
		if indicator.has("cell"):
			var cell_value: Variant = indicator["cell"]
			if cell_value is Vector2i:
				cell = cell_value
		var center: Vector2 = _cell_center(cell)
		var offset: float = float(cell_size) * 0.25
		var color: Color = destination_color
		if indicator_type == "invalid_target":
			color = invalid_color
		if indicator_type == "gather_target":
			draw_arc(center, offset, 0.0, TAU, 32, gather_color, 3.0)
			draw_line(center + Vector2(0.0, -offset), center + Vector2(0.0, offset), gather_color, 3.0)
			draw_line(center + Vector2(-offset, 0.0), center + Vector2(offset, 0.0), gather_color, 3.0)
		elif indicator_type == "build_target":
			draw_rect(_cell_rect(cell).grow(-10.0), Color(0.96, 0.64, 0.38, 0.2), true)
			draw_rect(_cell_rect(cell).grow(-10.0), build_color, false, 3.0)
		elif indicator_type == "attack_target":
			draw_arc(center, offset, 0.0, TAU, 24, attack_indicator_color, 3.0)
			draw_line(center + Vector2(-offset * 0.65, -offset * 0.65), center + Vector2(offset * 0.65, offset * 0.65), attack_indicator_color, 3.0)
			draw_line(center + Vector2(-offset * 0.65, offset * 0.65), center + Vector2(offset * 0.65, -offset * 0.65), attack_indicator_color, 3.0)
		elif indicator_type == "return_target":
			draw_arc(center, offset, PI * 0.15, PI * 1.85, 32, return_color, 3.0)
			draw_line(
				center + Vector2(-offset * 0.55, -offset * 0.2),
				center + Vector2(0.0, offset * 0.7),
				return_color,
				3.0
			)
			draw_line(
				center + Vector2(offset * 0.55, -offset * 0.2),
				center + Vector2(0.0, offset * 0.7),
				return_color,
				3.0
			)
		else:
			draw_line(center + Vector2(-offset, -offset), center + Vector2(offset, offset), color, 3.0)
			draw_line(center + Vector2(-offset, offset), center + Vector2(offset, -offset), color, 3.0)


func _draw_static_entities() -> void:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var entity_type: String = game_state.get_entity_type(entity)
		if entity_type == "resource_node":
			_draw_resource_node(entity)
			continue
		if entity_type == "stockpile":
			_draw_stockpile(entity)
			continue
		if entity_type == "structure":
			_draw_structure(entity)


func _draw_resource_node(entity: Dictionary) -> void:
	var resource_cell: Vector2i = game_state.get_entity_grid_position(entity)
	var rect: Rect2 = _cell_rect(resource_cell).grow(-8.0)
	var resource_type: String = game_state.get_entity_resource_type(entity)
	if resource_type == "stone":
		draw_rect(rect, stone_color, true)
		draw_rect(rect.grow(-10.0), Color("#b0bec5"), true)
		draw_rect(rect, Color("#37474f"), false, 2.0)
	else:
		draw_rect(rect, resource_color, true)
		draw_rect(rect.grow(-10.0), Color("#8fbf5a"), true)
		draw_rect(rect, Color("#243b1b"), false, 2.0)


func _draw_stockpile(entity: Dictionary) -> void:
	var stockpile_cell: Vector2i = game_state.get_entity_grid_position(entity)
	var rect: Rect2 = _cell_rect(stockpile_cell).grow(-6.0)
	draw_rect(rect, stockpile_color, true)
	draw_rect(rect.grow(-12.0), Color("#7cc6fe"), true)
	draw_rect(rect, Color("#112438"), false, 3.0)
	_draw_static_selection_outline(entity, rect)


func _draw_structure(entity: Dictionary) -> void:
	var structure_cell: Vector2i = game_state.get_entity_grid_position(entity)
	var rect: Rect2 = _cell_rect(structure_cell).grow(-7.0)
	var constructed: bool = game_state.get_entity_is_constructed(entity)
	var owner_id: int = game_state.get_entity_owner_id(entity, 1)
	var structure_type: String = game_state.get_entity_structure_type(entity)

	var base_color: Color = structure_color
	var inner_color: Color = Color("#d4a373")
	var border_color: Color = Color("#3b2413")
	if owner_id != 1:
		base_color = enemy_structure_color
		inner_color = Color("#c44")
		border_color = Color("#3b0000")
	else:
		var render_colors: Dictionary = GameDefinitionsClass.get_building_render_colors(structure_type)
		if not render_colors.is_empty():
			base_color = render_colors["base"]
			inner_color = render_colors["inner"]
			border_color = render_colors["border"]

	var fill_color: Color = base_color
	if not constructed:
		fill_color = Color(base_color.r, base_color.g, base_color.b, 0.55)
	draw_rect(rect, fill_color, true)
	draw_rect(rect.grow(-12.0), inner_color, true)
	draw_rect(rect, border_color, false, 3.0)

	if not constructed:
		var duration: int = maxi(game_state.get_entity_construction_duration_ticks(entity), 1)
		var progress: float = float(game_state.get_entity_construction_progress_ticks(entity)) / float(duration)
		var bar_rect: Rect2 = Rect2(
			rect.position + Vector2(8.0, rect.size.y - 10.0),
			Vector2(rect.size.x - 16.0, 6.0)
		)
		draw_rect(bar_rect, Color(0.15, 0.12, 0.08, 0.85), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), build_color, true)

	if entity.has("hp") and entity.has("max_hp"):
		var max_hp: int = maxi(game_state.get_entity_max_hp(entity), 1)
		var hp: int = game_state.get_entity_hp(entity)
		var hp_ratio: float = float(hp) / float(max_hp)
		var hp_bar_rect: Rect2 = Rect2(
			rect.position + Vector2(0.0, -8.0),
			Vector2(rect.size.x, 5.0)
		)
		draw_rect(hp_bar_rect, Color(0.1, 0.1, 0.1, 0.9), true)
		draw_rect(Rect2(hp_bar_rect.position, Vector2(hp_bar_rect.size.x * hp_ratio, hp_bar_rect.size.y)), Color("#e63946"), true)

	_draw_static_selection_outline(entity, rect)


func _draw_static_selection_outline(entity: Dictionary, rect: Rect2) -> void:
	var entity_id: int = game_state.get_entity_id(entity)
	if client_state.hovered_entity_id == entity_id:
		draw_rect(rect.grow(4.0), Color("#7bdff2"), false, 2.0)
	if client_state.selected_entity_ids.has(entity_id):
		draw_rect(rect.grow(7.0), selected_color, false, 4.0)


func _has_static_entity_at_cell(cell: Vector2i) -> bool:
	for entity_id in game_state.get_entities_by_type("resource_node"):
		var resource_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(resource_entity) == cell:
			return true
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var stockpile_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(stockpile_entity) == cell:
			return true
	for entity_id in game_state.get_entities_by_type("structure"):
		var structure_entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_grid_position(structure_entity) == cell:
			return true
	return false


func _draw_drag_selection() -> void:
	if not client_state.is_drag_selecting:
		return

	var selection_rect: Rect2 = client_state.get_drag_world_rect()
	draw_rect(selection_rect, Color(0.35, 0.67, 0.98, 0.12), true)
	draw_rect(selection_rect, Color("#59aaf9"), false, 2.0)


func _draw_selected_paths() -> void:
	for unit_id in client_state.selected_entity_ids:
		if not game_state.entities.has(unit_id):
			continue

		var entity: Dictionary = game_state.get_entity_dict(unit_id)
		var path_cells: Array[Vector2i] = game_state.get_entity_path_cells(entity)
		if path_cells.is_empty():
			continue

		var line_points: PackedVector2Array = []
		var current_cell: Vector2i = game_state.get_entity_grid_position(entity)
		line_points.append(_cell_center(current_cell))
		for path_cell in path_cells:
			line_points.append(_cell_center(path_cell))

		draw_polyline(line_points, Color(0.32, 0.80, 0.92, 0.7), 3.0)


func _draw_units() -> void:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue

		var authoritative_cell: Vector2i = game_state.get_entity_grid_position(entity)
		var authoritative_center: Vector2 = _cell_center(authoritative_cell)
		var visual_position: Vector2 = client_state.get_visual_unit_world_position(entity_id, authoritative_center)
		var unit_radius: float = float(cell_size) * 0.34

		var unit_role: String = game_state.get_entity_unit_role(entity)
		var fill_color: Color = unit_color
		if unit_role == "soldier":
			fill_color = soldier_color
		elif unit_role == "archer":
			fill_color = archer_color
		elif unit_role == "enemy_dummy":
			fill_color = enemy_unit_color

		draw_circle(visual_position, unit_radius, fill_color)
		draw_arc(visual_position, unit_radius, 0.0, TAU, 48, Color("#0f1216"), 4.0)
		if unit_role == "worker":
			draw_arc(visual_position, unit_radius - 8.0, 0.0, TAU, 48, Color("#c97d60"), 2.0)
		elif unit_role == "soldier":
			# Sword icon: vertical line
			draw_line(visual_position + Vector2(0.0, -unit_radius * 0.6), visual_position + Vector2(0.0, unit_radius * 0.4), Color("#ffccd5"), 3.0)
			draw_line(visual_position + Vector2(-unit_radius * 0.3, -unit_radius * 0.1), visual_position + Vector2(unit_radius * 0.3, -unit_radius * 0.1), Color("#ffccd5"), 2.0)
		elif unit_role == "archer":
			# Bow icon: arc shape
			draw_arc(visual_position + Vector2(-unit_radius * 0.15, 0.0), unit_radius * 0.45, -PI * 0.5, PI * 0.5, 12, Color("#e0f7fa"), 3.0)
			draw_line(visual_position + Vector2(-unit_radius * 0.15, -unit_radius * 0.45), visual_position + Vector2(-unit_radius * 0.15, unit_radius * 0.45), Color("#e0f7fa"), 2.0)
		elif unit_role == "enemy_dummy":
			draw_line(visual_position + Vector2(-unit_radius * 0.4, -unit_radius * 0.4), visual_position + Vector2(unit_radius * 0.4, unit_radius * 0.4), Color("#ff6666"), 3.0)
			draw_line(visual_position + Vector2(-unit_radius * 0.4, unit_radius * 0.4), visual_position + Vector2(unit_radius * 0.4, -unit_radius * 0.4), Color("#ff6666"), 3.0)

		if unit_role == "worker" and game_state.get_entity_carried_amount(entity) > 0:
			draw_circle(
				visual_position + Vector2(unit_radius * 0.45, -unit_radius * 0.45),
				unit_radius * 0.22,
				Color("#9a6b3f")
			)

		if entity.has("hp") and entity.has("max_hp"):
			var max_hp: int = maxi(game_state.get_entity_max_hp(entity), 1)
			var hp: int = game_state.get_entity_hp(entity)
			var hp_ratio: float = float(hp) / float(max_hp)
			var bar_width: float = unit_radius * 2.0
			var bar_y: float = visual_position.y + unit_radius + 5.0
			var bar_x: float = visual_position.x - unit_radius
			draw_rect(Rect2(bar_x, bar_y, bar_width, 4.0), Color(0.1, 0.1, 0.1, 0.85), true)
			var hp_color: Color = Color("#44cc44") if hp_ratio > 0.5 else (Color("#ffaa00") if hp_ratio > 0.25 else Color("#e63946"))
			draw_rect(Rect2(bar_x, bar_y, bar_width * hp_ratio, 4.0), hp_color, true)

		_draw_authoritative_marker(authoritative_center)

		if client_state.hovered_entity_id == entity_id:
			draw_arc(visual_position, unit_radius + 5.0, 0.0, TAU, 48, Color("#7bdff2"), 2.0)

		if client_state.selected_entity_ids.has(entity_id):
			draw_arc(visual_position, unit_radius + 10.0, 0.0, TAU, 48, selected_color, 4.0)


func _draw_authoritative_marker(center: Vector2) -> void:
	var marker_half_size: float = float(cell_size) * 0.10
	draw_rect(
		Rect2(
			center - Vector2.ONE * marker_half_size,
			Vector2.ONE * marker_half_size * 2.0
		),
		authoritative_cell_color,
		true
	)
	draw_rect(
		Rect2(
			center - Vector2.ONE * marker_half_size,
			Vector2.ONE * marker_half_size * 2.0
		),
		Color("#ffffff"),
		false,
		1.5
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * cell_size,
		(cell.y + 0.5) * cell_size
	)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size, cell.y * cell_size),
		Vector2.ONE * cell_size
	)
