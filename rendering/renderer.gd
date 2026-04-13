class_name GameRenderer
extends Node2D

## Rendering reads authoritative state and client state only.
## Presentation effects are client-side caches derived from authoritative deltas.

const GameDefinitionsClass = preload("res://simulation/game_definitions.gd")
const VisibilityClass = preload("res://simulation/visibility.gd")
const MatchConfigClass = preload("res://simulation/match_config.gd")
const AssetCatalogClass = preload("res://rendering/asset_catalog.gd")

const HIT_FLASH_DURATION: float = 0.30
const IMPACT_DURATION: float = 0.28
const PROJECTILE_DURATION: float = 0.22
const COMPLETION_PULSE_DURATION: float = 0.75
const IDLE_BOB_AMPLITUDE: float = 2.0
const IDLE_BOB_SPEED: float = 1.8

var game_state: GameState
var client_state: ClientState
var cell_size: int = 64
var _presentation_time: float = 0.0

## Recomputed once per _draw() call; reused for all per-entity visibility checks.
var _player_visible_cells: Dictionary = {}

## entity_id → true for enemy structures the player has ever observed.
## Client-side rendering memory only — not part of authoritative simulation.
var _seen_enemy_structures: Dictionary = {}

var _last_observed_tick: int = -1
var _last_hp_by_entity: Dictionary = {}
var _last_cooldown_by_entity: Dictionary = {}
var _last_constructed_by_entity: Dictionary = {}
var _hit_flash_timers: Dictionary = {}
var _impact_markers: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _completion_pulses: Array[Dictionary] = []

var grid_color: Color = Color("#344147")
var terrain_dark_color: Color = Color("#20272b")
var terrain_light_color: Color = Color("#242d31")
var terrain_moss_color: Color = Color("#27342d")
var hover_color: Color = Color(0.36, 0.49, 0.53, 0.18)
var unit_color: Color = Color("#d6d2c4")
var soldier_color: Color = Color("#4a7fc1")
var enemy_unit_color: Color = Color("#e84a1e")
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
var rally_color: Color = Color("#c77dff")
var structure_color: Color = Color("#a56b3a")
var enemy_structure_color: Color = Color("#c93a1a")
var shadow_color: Color = Color(0.02, 0.03, 0.04, 0.34)
var _world_textures: Dictionary = {}
var _particle_textures: Dictionary = {}


func configure(
	initial_game_state: GameState,
	initial_client_state: ClientState,
	initial_cell_size: int,
	cfg: MatchConfigClass = null
) -> void:
	game_state = initial_game_state
	client_state = initial_client_state
	cell_size = initial_cell_size
	if cfg != null:
		soldier_color = cfg.player_soldier_color
		unit_color = cfg.player_unit_color
		archer_color = cfg.player_archer_color
		stockpile_color = cfg.player_stockpile_color
		enemy_unit_color = cfg.enemy_unit_color
		enemy_structure_color = cfg.enemy_structure_color
	_load_assets()
	_reset_presentation_caches()
	_prime_presentation_snapshots()


func _load_assets() -> void:
	_world_textures = {
		"ground_a": AssetCatalogClass.get_world_texture("ground_a"),
		"ground_b": AssetCatalogClass.get_world_texture("ground_b"),
		"ground_c": AssetCatalogClass.get_world_texture("ground_c"),
		"grass_base_a": AssetCatalogClass.get_world_texture("grass_base_a"),
		"grass_base_b": AssetCatalogClass.get_world_texture("grass_base_b"),
		"sand_base_a": AssetCatalogClass.get_world_texture("sand_base_a"),
		"sand_base_b": AssetCatalogClass.get_world_texture("sand_base_b"),
		"dirt_base_a": AssetCatalogClass.get_world_texture("dirt_base_a"),
		"dirt_base_b": AssetCatalogClass.get_world_texture("dirt_base_b"),
		"stone_base_a": AssetCatalogClass.get_world_texture("stone_base_a"),
		"stone_base_b": AssetCatalogClass.get_world_texture("stone_base_b"),
		"road_full_straight_v": AssetCatalogClass.get_world_texture("road_full_straight_v"),
		"road_full_straight_h": AssetCatalogClass.get_world_texture("road_full_straight_h"),
		"road_full_cross": AssetCatalogClass.get_world_texture("road_full_cross"),
		"road_overlay_v": AssetCatalogClass.get_world_texture("road_overlay_v"),
		"road_overlay_h": AssetCatalogClass.get_world_texture("road_overlay_h"),
		"road_overlay_cross": AssetCatalogClass.get_world_texture("road_overlay_cross"),
		"tree_single_round": AssetCatalogClass.get_world_texture("tree_single_round"),
		"tree_cluster_round": AssetCatalogClass.get_world_texture("tree_cluster_round"),
		"pine_single": AssetCatalogClass.get_world_texture("pine_single"),
		"pine_cluster": AssetCatalogClass.get_world_texture("pine_cluster"),
		"stone_node_small": AssetCatalogClass.get_world_texture("stone_node_small"),
		"stone_node_large": AssetCatalogClass.get_world_texture("stone_node_large"),
		"farm_small_brown": AssetCatalogClass.get_world_texture("farm_small_brown"),
		"farm_small_light": AssetCatalogClass.get_world_texture("farm_small_light"),
		"farm_large_brown": AssetCatalogClass.get_world_texture("farm_large_brown"),
		"farm_large_light": AssetCatalogClass.get_world_texture("farm_large_light"),
		"obstacle": AssetCatalogClass.get_world_texture("obstacle"),
		"wood": AssetCatalogClass.get_world_texture("wood"),
		"stone": AssetCatalogClass.get_world_texture("stone"),
		"stockpile": AssetCatalogClass.get_world_texture("stockpile"),
		"house": AssetCatalogClass.get_world_texture("house"),
		"farm": AssetCatalogClass.get_world_texture("farm"),
		"barracks": AssetCatalogClass.get_world_texture("barracks"),
		"archery_range": AssetCatalogClass.get_world_texture("archery_range"),
		"enemy_base": AssetCatalogClass.get_world_texture("enemy_base"),
		"worker": AssetCatalogClass.get_world_texture("worker"),
		"soldier": AssetCatalogClass.get_world_texture("soldier"),
		"archer": AssetCatalogClass.get_world_texture("archer"),
		"enemy_unit": AssetCatalogClass.get_world_texture("enemy_unit"),
	}
	_particle_textures = {
		"impact": AssetCatalogClass.get_particle_texture("impact"),
		"completion": AssetCatalogClass.get_particle_texture("completion"),
		"projectile": AssetCatalogClass.get_particle_texture("projectile"),
		"dust": AssetCatalogClass.get_particle_texture("dust"),
	}


func _process(delta: float) -> void:
	if game_state == null:
		return
	_presentation_time += delta
	_observe_tick_deltas()
	_advance_presentation_effects(delta)


func _draw() -> void:
	if game_state == null or client_state == null:
		return
	_player_visible_cells = VisibilityClass.compute_visible_cells(game_state, 1)

	_draw_ground()
	_draw_obstacles()
	_draw_static_entities()
	_draw_hover_cell()
	_draw_placement_preview()
	_draw_drag_selection()
	_draw_destination_indicators()
	_draw_selected_paths()
	_draw_selected_attack_links()
	_draw_selected_producer_rally()
	_draw_selected_attack_ranges()
	_draw_projectiles()
	_draw_units()
	_draw_completion_pulses()
	_draw_impact_markers()


func _reset_presentation_caches() -> void:
	_last_observed_tick = -1
	_last_hp_by_entity.clear()
	_last_cooldown_by_entity.clear()
	_last_constructed_by_entity.clear()
	_hit_flash_timers.clear()
	_impact_markers.clear()
	_projectiles.clear()
	_completion_pulses.clear()


func _prime_presentation_snapshots() -> void:
	if game_state == null:
		return
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		_last_hp_by_entity[entity_id] = game_state.get_entity_hp(entity)
		_last_constructed_by_entity[entity_id] = game_state.get_entity_is_constructed(entity)
		if game_state.get_entity_type(entity) == "unit":
			_last_cooldown_by_entity[entity_id] = game_state.get_entity_attack_cooldown_remaining(entity)
	_last_observed_tick = game_state.current_tick


func _observe_tick_deltas() -> void:
	if game_state.current_tick == _last_observed_tick:
		return

	var next_hp: Dictionary = {}
	var next_constructed: Dictionary = {}
	var next_cooldown: Dictionary = {}
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()

	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var hp: int = game_state.get_entity_hp(entity)
		var constructed: bool = game_state.get_entity_is_constructed(entity)
		next_hp[entity_id] = hp
		next_constructed[entity_id] = constructed

		if _last_hp_by_entity.has(entity_id):
			var previous_hp: int = int(_last_hp_by_entity[entity_id])
			if hp < previous_hp:
				_register_hit_effect(entity)

		if _last_constructed_by_entity.has(entity_id):
			var was_constructed: bool = bool(_last_constructed_by_entity[entity_id])
			if not was_constructed and constructed:
				_register_completion_pulse(entity)

		if game_state.get_entity_type(entity) == "unit":
			var cooldown: int = game_state.get_entity_attack_cooldown_remaining(entity)
			next_cooldown[entity_id] = cooldown
			var previous_cooldown: int = 0
			if _last_cooldown_by_entity.has(entity_id):
				previous_cooldown = int(_last_cooldown_by_entity[entity_id])
			if cooldown > previous_cooldown and game_state.get_entity_can_attack(entity):
				_register_attack_effect(entity)

	_last_hp_by_entity = next_hp
	_last_constructed_by_entity = next_constructed
	_last_cooldown_by_entity = next_cooldown
	_prune_missing_flash_entities()
	_last_observed_tick = game_state.current_tick


func _prune_missing_flash_entities() -> void:
	var valid_ids: Array = _last_hp_by_entity.keys()
	valid_ids.sort()
	var valid_lookup: Dictionary = {}
	for entity_id in valid_ids:
		valid_lookup[entity_id] = true
	var current_ids: Array = _hit_flash_timers.keys()
	current_ids.sort()
	for entity_id in current_ids:
		if not valid_lookup.has(entity_id):
			_hit_flash_timers.erase(entity_id)


func _advance_presentation_effects(delta: float) -> void:
	var flash_ids: Array = _hit_flash_timers.keys()
	flash_ids.sort()
	for entity_id in flash_ids:
		var remaining: float = float(_hit_flash_timers[entity_id]) - delta
		if remaining <= 0.0:
			_hit_flash_timers.erase(entity_id)
		else:
			_hit_flash_timers[entity_id] = remaining

	_decay_effect_array(_impact_markers, delta)
	_decay_effect_array(_projectiles, delta)
	_decay_effect_array(_completion_pulses, delta)


func _decay_effect_array(effects: Array[Dictionary], delta: float) -> void:
	var survivors: Array[Dictionary] = []
	for effect in effects:
		var next_effect: Dictionary = effect.duplicate(true)
		var elapsed: float = float(next_effect.get("elapsed", 0.0)) + delta
		var duration: float = float(next_effect.get("duration", 0.2))
		next_effect["elapsed"] = elapsed
		if elapsed < duration:
			survivors.append(next_effect)
	effects.clear()
	for effect in survivors:
		effects.append(effect)


func _register_hit_effect(entity: Dictionary) -> void:
	var entity_id: int = game_state.get_entity_id(entity)
	var center: Vector2 = _cell_center(game_state.get_entity_grid_position(entity))
	_hit_flash_timers[entity_id] = HIT_FLASH_DURATION
	_impact_markers.append({
		"center": center,
		"duration": IMPACT_DURATION,
		"elapsed": 0.0,
		"color": attack_indicator_color,
	})


func _register_completion_pulse(entity: Dictionary) -> void:
	_completion_pulses.append({
		"center": _cell_center(game_state.get_entity_grid_position(entity)),
		"duration": COMPLETION_PULSE_DURATION,
		"elapsed": 0.0,
		"color": selected_color,
	})


func _register_attack_effect(attacker: Dictionary) -> void:
	var target_id: int = game_state.get_entity_attack_target_id(attacker)
	if target_id == 0 or not game_state.entities.has(target_id):
		return
	var attacker_center: Vector2 = _cell_center(game_state.get_entity_grid_position(attacker))
	var target_entity: Dictionary = game_state.get_entity_dict(target_id)
	var target_center: Vector2 = _cell_center(game_state.get_entity_grid_position(target_entity))
	if game_state.get_entity_attack_range_cells(attacker) > 1:
		_projectiles.append({
			"start": attacker_center,
			"end": target_center,
			"duration": PROJECTILE_DURATION,
			"elapsed": 0.0,
			"color": archer_color.lightened(0.2),
		})
	else:
		_impact_markers.append({
			"center": target_center,
			"duration": IMPACT_DURATION,
			"elapsed": 0.0,
			"color": Color("#ffd6a5"),
		})


func _draw_ground() -> void:
	var width: int = game_state.get_map_width()
	var height: int = game_state.get_map_height()
	var map_width_pixels: int = width * cell_size
	var map_height_pixels: int = height * cell_size
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(map_width_pixels, map_height_pixels)),
		terrain_dark_color,
		true
	)

	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = _cell_rect(cell)
			var tint: float = _cell_noise(cell)
			var base_tile_key: String = _get_base_terrain_texture_key(cell)
			var mixed: Color = _get_base_terrain_modulate(cell, base_tile_key)
			if not _draw_world_texture(base_tile_key, rect, mixed):
				draw_rect(rect, mixed, true)
				draw_rect(
					rect.grow(-float(cell_size) * 0.34),
					Color(1.0, 1.0, 1.0, 0.015 + tint * 0.02),
					true
				)
			_draw_terrain_overlays(cell, rect)

	for x in range(width + 1):
		var world_x: float = float(x * cell_size)
		draw_line(Vector2(world_x, 0.0), Vector2(world_x, map_height_pixels), grid_color, 1.0)
	for y in range(height + 1):
		var world_y: float = float(y * cell_size)
		draw_line(Vector2(0.0, world_y), Vector2(map_width_pixels, world_y), grid_color, 1.0)


func _get_base_terrain_texture_key(cell: Vector2i) -> String:
	if _is_near_structure(cell, 2):
		return "dirt_base_a" if (cell.x + cell.y) % 2 == 0 else "dirt_base_b"
	if _is_near_blocked(cell, 1) or _is_near_resource_type(cell, "stone", 2):
		return "stone_base_a" if cell.x % 2 == 0 else "stone_base_b"
	var region_noise: float = _region_noise(cell, 4)
	if region_noise > 0.74:
		return "sand_base_a" if (cell.x + cell.y) % 2 == 0 else "sand_base_b"
	return "grass_base_a" if (cell.x + cell.y) % 2 == 0 else "grass_base_b"


func _get_base_terrain_modulate(cell: Vector2i, texture_key: String) -> Color:
	var tint: float = _cell_noise(cell)
	if texture_key.begins_with("grass"):
		return terrain_light_color.lerp(terrain_moss_color, 0.22 + tint * 0.12)
	if texture_key.begins_with("dirt"):
		return Color("#6d5842").lerp(Color("#8a7354"), tint * 0.30)
	if texture_key.begins_with("stone"):
		return Color("#5d666d").lerp(Color("#78838a"), tint * 0.24)
	return Color("#9f8d69").lerp(Color("#c3b08a"), tint * 0.18)


func _draw_terrain_overlays(cell: Vector2i, rect: Rect2) -> void:
	if _is_farm_cell(cell):
		var farm_key: String = "farm_small_brown" if (cell.x + cell.y) % 2 == 0 else "farm_small_light"
		_draw_world_texture(farm_key, rect.grow(-3.0), Color(1.0, 1.0, 1.0, 0.88))
		return

	var road_kind: String = _get_road_texture_key(cell)
	if road_kind != "":
		_draw_world_texture(road_kind, rect, Color(1.0, 1.0, 1.0, 0.92))
		return

	var overlay_key: String = _get_road_overlay_texture_key(cell)
	if overlay_key != "":
		_draw_world_texture(overlay_key, rect, Color(1.0, 1.0, 1.0, 0.34))
		return

	if _should_draw_tree_decoration(cell):
		var decor_key: String = "tree_single_round" if _cell_noise(cell) < 0.55 else "pine_single"
		_draw_world_texture(decor_key, rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.42))


func _get_road_texture_key(cell: Vector2i) -> String:
	var road_neighbors: Dictionary = _get_road_neighbor_flags(cell)
	var has_vertical: bool = bool(road_neighbors.get("up", false)) or bool(road_neighbors.get("down", false))
	var has_horizontal: bool = bool(road_neighbors.get("left", false)) or bool(road_neighbors.get("right", false))
	if has_vertical and has_horizontal:
		return "road_full_cross"
	if has_vertical:
		return "road_full_straight_v"
	if has_horizontal:
		return "road_full_straight_h"
	return ""


func _get_road_overlay_texture_key(cell: Vector2i) -> String:
	if _is_road_cell(cell):
		return ""
	var neighbor_flags: Dictionary = _get_road_neighbor_flags(cell)
	var touches_vertical: bool = bool(neighbor_flags.get("up", false)) or bool(neighbor_flags.get("down", false))
	var touches_horizontal: bool = bool(neighbor_flags.get("left", false)) or bool(neighbor_flags.get("right", false))
	if touches_vertical and touches_horizontal:
		return "road_overlay_cross"
	if touches_vertical:
		return "road_overlay_v"
	if touches_horizontal:
		return "road_overlay_h"
	return ""


func _get_road_neighbor_flags(cell: Vector2i) -> Dictionary:
	return {
		"up": _is_road_cell(cell + Vector2i(0, -1)),
		"down": _is_road_cell(cell + Vector2i(0, 1)),
		"left": _is_road_cell(cell + Vector2i(-1, 0)),
		"right": _is_road_cell(cell + Vector2i(1, 0)),
	}


func _is_road_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= game_state.get_map_width() or cell.y >= game_state.get_map_height():
		return false
	if _is_farm_cell(cell):
		return false
	var static_entity_id: int = game_state.get_selectable_entity_id_at_cell(cell)
	if static_entity_id != 0:
		return true
	if _is_adjacent_to_structure_or_stockpile(cell):
		return true
	var nearest_resource: Dictionary = _get_nearest_resource(cell)
	if not nearest_resource.is_empty():
		var resource_distance: int = int(nearest_resource.get("distance", 99))
		if resource_distance <= 1 and _is_near_structure(cell, 5):
			return true
	return false


func _is_adjacent_to_structure_or_stockpile(cell: Vector2i) -> bool:
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var test_cell: Vector2i = Vector2i(x, y)
			if game_state.get_selectable_entity_id_at_cell(test_cell) != 0:
				return true
	return false


func _is_farm_cell(cell: Vector2i) -> bool:
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_structure_type(entity) != "farm":
			continue
		if game_state.get_entity_grid_position(entity) == cell:
			return true
	return false


func _is_near_structure(cell: Vector2i, radius: int) -> bool:
	for entity_id in game_state.get_entities_by_type("stockpile"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if _cell_distance(cell, game_state.get_entity_grid_position(entity)) <= radius:
			return true
	for entity_id in game_state.get_entities_by_type("structure"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if _cell_distance(cell, game_state.get_entity_grid_position(entity)) <= radius:
			return true
	return false


func _is_near_blocked(cell: Vector2i, radius: int) -> bool:
	var blocked_cells: Dictionary = game_state.get_blocked_cells()
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			if blocked_cells.has(game_state.cell_key(Vector2i(x, y))):
				return true
	return false


func _is_near_resource_type(cell: Vector2i, resource_type: String, radius: int) -> bool:
	for entity_id in game_state.get_entities_by_type("resource_node"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_resource_type(entity) != resource_type:
			continue
		if _cell_distance(cell, game_state.get_entity_grid_position(entity)) <= radius:
			return true
	return false


func _get_nearest_resource(cell: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: int = 9999
	for entity_id in game_state.get_entities_by_type("resource_node"):
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		var resource_cell: Vector2i = game_state.get_entity_grid_position(entity)
		var distance: int = _cell_distance(cell, resource_cell)
		if distance < best_distance:
			best_distance = distance
			best = {
				"distance": distance,
				"type": game_state.get_entity_resource_type(entity),
			}
	return best


func _should_draw_tree_decoration(cell: Vector2i) -> bool:
	if _is_near_structure(cell, 2):
		return false
	if _is_near_blocked(cell, 1):
		return false
	if _has_static_entity_at_cell(cell):
		return false
	if _is_road_cell(cell):
		return false
	if _region_noise(cell, 3) < 0.81:
		return false
	return _get_base_terrain_texture_key(cell).begins_with("grass")


func _draw_hover_cell() -> void:
	if client_state.hover_cell.x < 0 or client_state.hover_cell.y < 0:
		return
	var rect: Rect2 = _cell_rect(client_state.hover_cell)
	var color: Color = hover_color
	if game_state.is_cell_blocked(client_state.hover_cell):
		color = Color(0.94, 0.28, 0.44, 0.18)
	draw_rect(rect, color, true)
	draw_rect(rect.grow(-4.0), Color(color.r, color.g, color.b, 0.36), false, 2.0)


func _draw_placement_preview() -> void:
	if not client_state.is_in_structure_placement_mode():
		return
	if client_state.placement_preview_cell.x < 0 or client_state.placement_preview_cell.y < 0:
		return

	var rect: Rect2 = _cell_rect(client_state.placement_preview_cell).grow(-4.0)
	var fill_color: Color = Color(0.96, 0.64, 0.38, 0.20)
	var outline_color: Color = build_color
	if not client_state.placement_preview_valid:
		fill_color = Color(0.94, 0.28, 0.44, 0.20)
		outline_color = invalid_color
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, 3.0)
	_draw_scaffold_lines(rect, Color(outline_color.r, outline_color.g, outline_color.b, 0.55))


func _draw_obstacles() -> void:
	var blocked_cells: Dictionary = game_state.get_blocked_cells()
	var keys: Array = blocked_cells.keys()
	keys.sort()
	for key in keys:
		var parts: PackedStringArray = String(key).split(",")
		var cell: Vector2i = Vector2i(parts[0].to_int(), parts[1].to_int())
		if _has_static_entity_at_cell(cell):
			continue
		_draw_obstacle_cell(cell)


func _draw_obstacle_cell(cell: Vector2i) -> void:
	var rect: Rect2 = _cell_rect(cell).grow(-4.0)
	var center: Vector2 = rect.get_center()
	_draw_shadow(center, Vector2(rect.size.x * 0.42, rect.size.y * 0.18))
	var texture_key: String = "obstacle"
	if _cell_noise(cell) > 0.55 and _world_textures.has("pine_single"):
		texture_key = "pine_single"
	if _draw_world_texture(texture_key, rect, Color(1.0, 1.0, 1.0, 0.95)):
		draw_rect(rect, Color(0.08, 0.08, 0.09, 0.20), false, 2.0)
		return
	draw_rect(rect, obstacle_color.darkened(0.12), true)
	var poly_a: PackedVector2Array = PackedVector2Array([
		rect.position + Vector2(6.0, rect.size.y * 0.65),
		rect.position + Vector2(rect.size.x * 0.32, 8.0),
		rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.22),
		rect.position + Vector2(rect.size.x * 0.46, rect.size.y - 7.0),
	])
	var poly_b: PackedVector2Array = PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.78),
		rect.position + Vector2(rect.size.x * 0.72, 10.0),
		rect.position + Vector2(rect.size.x - 8.0, rect.size.y * 0.56),
		rect.position + Vector2(rect.size.x * 0.78, rect.size.y - 6.0),
	])
	draw_colored_polygon(poly_a, obstacle_edge_color)
	draw_colored_polygon(poly_b, obstacle_edge_color.darkened(0.1))
	draw_polyline(_closed_polyline(poly_a), Color("#d7d9c5"), 2.0)
	draw_polyline(_closed_polyline(poly_b), Color("#d7d9c5"), 2.0)


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
			and indicator_type != "rally_target"
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
			_draw_target_ring(center, offset, gather_color)
			draw_line(center + Vector2(0.0, -offset), center + Vector2(0.0, offset), gather_color, 3.0)
			draw_line(center + Vector2(-offset, 0.0), center + Vector2(offset, 0.0), gather_color, 3.0)
		elif indicator_type == "build_target":
			var build_rect: Rect2 = _cell_rect(cell).grow(-10.0)
			draw_rect(build_rect, Color(0.96, 0.64, 0.38, 0.2), true)
			draw_rect(build_rect, build_color, false, 3.0)
		elif indicator_type == "rally_target":
			_draw_target_ring(center, offset, rally_color)
			_draw_arrowhead(center + Vector2(offset * 0.55, 0.0), rally_color, 10.0)
		elif indicator_type == "attack_target":
			_draw_target_ring(center, offset, attack_indicator_color)
			draw_line(center + Vector2(-offset * 0.65, -offset * 0.65), center + Vector2(offset * 0.65, offset * 0.65), attack_indicator_color, 3.0)
			draw_line(center + Vector2(-offset * 0.65, offset * 0.65), center + Vector2(offset * 0.65, -offset * 0.65), attack_indicator_color, 3.0)
		elif indicator_type == "return_target":
			_draw_target_ring(center, offset, return_color)
			draw_line(center + Vector2(-offset * 0.55, -offset * 0.2), center + Vector2(0.0, offset * 0.7), return_color, 3.0)
			draw_line(center + Vector2(offset * 0.55, -offset * 0.2), center + Vector2(0.0, offset * 0.7), return_color, 3.0)
		else:
			draw_circle(center, offset * 0.18, color)
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
		elif entity_type == "stockpile":
			_draw_stockpile(entity)
		elif entity_type == "structure":
			_draw_structure(entity)


func _draw_resource_node(entity: Dictionary) -> void:
	var cell: Vector2i = game_state.get_entity_grid_position(entity)
	var center: Vector2 = _cell_center(cell)
	var rect: Rect2 = _cell_rect(cell).grow(-8.0)
	var resource_type: String = game_state.get_entity_resource_type(entity)
	var depleted: bool = game_state.get_entity_is_depleted(entity)
	var alpha: float = 0.35 if depleted else 1.0
	_draw_shadow(center + Vector2(0.0, 8.0), Vector2(rect.size.x * 0.33, rect.size.y * 0.12))
	var texture_key: String = _get_resource_texture_key(resource_type, cell)
	var draw_rect: Rect2 = rect.grow(6.0)
	if _draw_world_texture(texture_key, draw_rect, Color(1.0, 1.0, 1.0, alpha)):
		if client_state.hovered_entity_id == game_state.get_entity_id(entity):
			draw_arc(center, float(cell_size) * 0.34, 0.0, TAU, 24, Color("#7bdff2"), 2.0)
		return
	if resource_type == "stone":
		var rock_a: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(8.0, rect.size.y * 0.75),
			rect.position + Vector2(rect.size.x * 0.32, 10.0),
			rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.48),
			rect.position + Vector2(rect.size.x * 0.44, rect.size.y - 8.0),
		])
		var rock_b: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(rect.size.x * 0.46, rect.size.y * 0.8),
			rect.position + Vector2(rect.size.x * 0.68, 8.0),
			rect.position + Vector2(rect.size.x - 8.0, rect.size.y * 0.58),
			rect.position + Vector2(rect.size.x * 0.78, rect.size.y - 8.0),
		])
		draw_colored_polygon(rock_a, Color(stone_color.r, stone_color.g, stone_color.b, alpha))
		draw_colored_polygon(rock_b, Color(0.73, 0.77, 0.78, alpha))
		draw_polyline(_closed_polyline(rock_a), Color(0.2, 0.24, 0.28, alpha), 2.0)
		draw_polyline(_closed_polyline(rock_b), Color(0.2, 0.24, 0.28, alpha), 2.0)
	else:
		draw_rect(Rect2(center.x - 4.0, center.y - 2.0, 8.0, 18.0), Color(0.29, 0.18, 0.10, alpha), true)
		draw_circle(center + Vector2(-10.0, -4.0), 14.0, Color(resource_color.r, resource_color.g, resource_color.b, alpha))
		draw_circle(center + Vector2(8.0, -7.0), 13.0, Color(0.49, 0.70, 0.34, alpha))
		draw_circle(center + Vector2(-1.0, -15.0), 14.0, Color(0.56, 0.78, 0.37, alpha))
	if client_state.hovered_entity_id == game_state.get_entity_id(entity):
		draw_arc(center, float(cell_size) * 0.34, 0.0, TAU, 24, Color("#7bdff2"), 2.0)


func _draw_stockpile(entity: Dictionary) -> void:
	_draw_structure_like(entity, stockpile_color, Color("#7cc6fe"), Color("#112438"), true)


func _draw_structure(entity: Dictionary) -> void:
	var cell: Vector2i = game_state.get_entity_grid_position(entity)
	var owner_id: int = game_state.get_entity_owner_id(entity, 1)
	if owner_id != 1:
		var entity_id: int = game_state.get_entity_id(entity)
		var in_vision: bool = _player_visible_cells.has(game_state.cell_key(cell))
		if in_vision:
			_seen_enemy_structures[entity_id] = true
		elif _seen_enemy_structures.has(entity_id):
			_draw_ghost_structure(cell)
			return
		else:
			return

	var structure_type: String = game_state.get_entity_structure_type(entity)
	var render_colors: Dictionary = GameDefinitionsClass.get_building_render_colors(structure_type)
	var base_color: Color = structure_color
	var inner_color: Color = Color("#d4a373")
	var border_color: Color = Color("#3b2413")
	if owner_id != 1:
		base_color = enemy_structure_color
		inner_color = enemy_unit_color.lightened(0.2)
		border_color = enemy_structure_color.darkened(0.55)
	elif not render_colors.is_empty():
		base_color = render_colors["base"]
		inner_color = render_colors["inner"]
		border_color = render_colors["border"]

	_draw_structure_like(entity, base_color, inner_color, border_color, false)


func _draw_structure_like(
	entity: Dictionary,
	base_color: Color,
	inner_color: Color,
	border_color: Color,
	is_stockpile: bool
) -> void:
	var cell: Vector2i = game_state.get_entity_grid_position(entity)
	var center: Vector2 = _cell_center(cell)
	var rect: Rect2 = _cell_rect(cell).grow(-2.0)
	var constructed: bool = game_state.get_entity_is_constructed(entity)
	var structure_type: String = game_state.get_entity_structure_type(entity)
	var flash_alpha: float = _get_hit_flash_alpha(game_state.get_entity_id(entity))
	var owner_id: int = game_state.get_entity_owner_id(entity, 1)
	var accent_color: Color = unit_color if owner_id == 1 else enemy_unit_color

	_draw_shadow(center + Vector2(0.0, 10.0), Vector2(rect.size.x * 0.42, rect.size.y * 0.16))
	var fill_color: Color = base_color if constructed else Color(base_color.r, base_color.g, base_color.b, 0.58)
	fill_color = fill_color.lerp(Color.WHITE, flash_alpha * 0.55)
	var texture_key: String = _get_structure_texture_key(structure_type, is_stockpile, owner_id)
	if not _draw_world_texture(texture_key, rect, fill_color):
		draw_rect(rect, fill_color, true)
		draw_rect(rect, border_color, false, 3.0)
		_draw_structure_shape(structure_type, rect, inner_color, border_color, accent_color, is_stockpile, owner_id)
	else:
		draw_rect(rect, Color(border_color.r, border_color.g, border_color.b, 0.48), false, 2.0)
		if owner_id != 1:
			draw_rect(rect.grow(-8.0), Color(enemy_unit_color.r, enemy_unit_color.g, enemy_unit_color.b, 0.16), false, 2.0)

	if not constructed:
		_draw_scaffold_lines(rect.grow(-4.0), Color(0.96, 0.84, 0.55, 0.55))
		_draw_construction_bar(entity, rect)

	if _should_draw_structure_bars(entity):
		_draw_structure_hp_bar(entity, rect)
	_draw_structure_production_bar(entity, rect)
	_draw_static_selection_outline(entity, rect)


func _draw_structure_shape(
	structure_type: String,
	rect: Rect2,
	inner_color: Color,
	border_color: Color,
	accent_color: Color,
	is_stockpile: bool,
	owner_id: int
) -> void:
	if is_stockpile or structure_type == "stockpile":
		var roof: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(rect.size.x * 0.10, rect.size.y * 0.45),
			rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.08),
			rect.position + Vector2(rect.size.x * 0.90, rect.size.y * 0.45),
		])
		draw_colored_polygon(roof, inner_color)
		draw_rect(Rect2(rect.position + Vector2(10.0, rect.size.y * 0.45), Vector2(rect.size.x - 20.0, rect.size.y * 0.38)), inner_color.darkened(0.1), true)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.18), Vector2(7.0, rect.size.y * 0.24)), accent_color, true)
		return

	if structure_type == "house":
		var house_body: Rect2 = Rect2(rect.position + Vector2(11.0, rect.size.y * 0.42), Vector2(rect.size.x - 22.0, rect.size.y * 0.34))
		var house_roof: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(9.0, rect.size.y * 0.46),
			rect.position + Vector2(rect.size.x * 0.50, 10.0),
			rect.position + Vector2(rect.size.x - 9.0, rect.size.y * 0.46),
		])
		draw_rect(house_body, inner_color, true)
		draw_colored_polygon(house_roof, inner_color.lightened(0.18))
		draw_rect(Rect2(house_body.position + Vector2(house_body.size.x * 0.42, house_body.size.y * 0.35), Vector2(10.0, house_body.size.y * 0.65)), border_color, true)
		return

	if structure_type == "farm":
		var plot: Rect2 = rect.grow(-10.0)
		draw_rect(plot, inner_color.darkened(0.18), true)
		for index in range(4):
			var y: float = plot.position.y + 8.0 + float(index) * ((plot.size.y - 16.0) / 3.0)
			draw_line(Vector2(plot.position.x + 5.0, y), Vector2(plot.position.x + plot.size.x - 5.0, y + 3.0), Color("#9bcf53"), 2.0)
		draw_rect(plot, Color("#6b4f30"), false, 2.0)
		return

	if structure_type == "barracks":
		var body: Rect2 = rect.grow(-10.0)
		draw_rect(body, inner_color, true)
		for step in range(4):
			var battlement_rect: Rect2 = Rect2(
				body.position + Vector2(4.0 + float(step) * ((body.size.x - 14.0) / 3.0), -6.0),
				Vector2(8.0, 8.0)
			)
			draw_rect(battlement_rect, inner_color.lightened(0.12), true)
		draw_rect(Rect2(body.position + Vector2(body.size.x * 0.40, body.size.y * 0.48), Vector2(body.size.x * 0.20, body.size.y * 0.52)), border_color, true)
		draw_rect(Rect2(body.position + Vector2(8.0, 10.0), Vector2(body.size.x - 16.0, 5.0)), accent_color.darkened(0.18), true)
		return

	if structure_type == "archery_range":
		var deck: Rect2 = Rect2(rect.position + Vector2(9.0, rect.size.y * 0.52), Vector2(rect.size.x - 18.0, rect.size.y * 0.22))
		draw_rect(deck, inner_color, true)
		draw_line(rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.52), rect.position + Vector2(rect.size.x * 0.24, rect.size.y * 0.18), border_color, 4.0)
		draw_line(rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.52), rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.18), border_color, 4.0)
		draw_arc(rect.get_center() + Vector2(0.0, -4.0), rect.size.x * 0.14, -PI * 0.5, PI * 0.5, 16, accent_color, 3.0)
		draw_line(rect.get_center() + Vector2(0.0, -12.0), rect.get_center() + Vector2(0.0, 4.0), accent_color, 2.0)
		return

	draw_rect(rect.grow(-12.0), inner_color, true)
	if owner_id == 1:
		draw_rect(Rect2(rect.position + Vector2(10.0, 10.0), Vector2(rect.size.x - 20.0, 5.0)), accent_color.darkened(0.14), true)


func _draw_construction_bar(entity: Dictionary, rect: Rect2) -> void:
	var duration: int = maxi(game_state.get_entity_construction_duration_ticks(entity), 1)
	var progress: float = float(game_state.get_entity_construction_progress_ticks(entity)) / float(duration)
	var bar_rect: Rect2 = Rect2(rect.position + Vector2(8.0, rect.size.y - 10.0), Vector2(rect.size.x - 16.0, 6.0))
	draw_rect(bar_rect, Color(0.15, 0.12, 0.08, 0.85), true)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), build_color, true)


func _draw_structure_production_bar(entity: Dictionary, rect: Rect2) -> void:
	var produced_unit_type: String = game_state.get_entity_produced_unit_type(entity)
	var duration: int = game_state.get_entity_production_duration_ticks(entity)
	var progress_ticks: int = game_state.get_entity_production_progress_ticks(entity)
	var blocked: bool = game_state.get_entity_is_production_blocked(entity)
	var queue_count: int = game_state.get_entity_production_queue_count(entity)
	var entity_id: int = game_state.get_entity_id(entity)
	var hovered: bool = client_state.hovered_entity_id == entity_id
	var selected: bool = client_state.selected_entity_ids.has(entity_id)
	if produced_unit_type == "" and queue_count <= 0 and not blocked:
		return
	if not hovered and not selected and queue_count <= 0 and not blocked:
		return
	var bar_rect: Rect2 = Rect2(rect.position + Vector2(8.0, rect.size.y + 5.0), Vector2(rect.size.x - 16.0, 5.0))
	draw_rect(bar_rect, Color(0.08, 0.08, 0.10, 0.85), true)
	if duration > 0 and progress_ticks > 0:
		var progress: float = float(progress_ticks) / float(duration)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * progress, bar_rect.size.y)), rally_color, true)
	if blocked:
		draw_rect(bar_rect.grow(1.0), invalid_color, false, 2.0)
	if queue_count > 0:
		var badge_rect: Rect2 = Rect2(rect.position + Vector2(rect.size.x - 18.0, 2.0), Vector2(16.0, 16.0))
		draw_rect(badge_rect, Color(0.07, 0.08, 0.10, 0.92), true)
		draw_rect(badge_rect, rally_color, false, 2.0)
		var dots: int = mini(queue_count, 3)
		for index in range(dots):
			draw_circle(
				badge_rect.position + Vector2(5.0 + float(index) * 4.0, 8.0),
				1.4,
				Color.WHITE
			)


func _draw_structure_hp_bar(entity: Dictionary, rect: Rect2) -> void:
	var max_hp: int = maxi(game_state.get_entity_max_hp(entity), 1)
	var hp: int = game_state.get_entity_hp(entity)
	var hp_ratio: float = float(hp) / float(max_hp)
	var hp_bar_rect: Rect2 = Rect2(rect.position + Vector2(0.0, -8.0), Vector2(rect.size.x, 5.0))
	draw_rect(hp_bar_rect, Color(0.1, 0.1, 0.1, 0.9), true)
	draw_rect(Rect2(hp_bar_rect.position, Vector2(hp_bar_rect.size.x * hp_ratio, hp_bar_rect.size.y)), _hp_bar_color(hp_ratio), true)


func _draw_ghost_structure(cell: Vector2i) -> void:
	var rect: Rect2 = _cell_rect(cell).grow(-7.0)
	_draw_shadow(rect.get_center() + Vector2(0.0, 10.0), Vector2(rect.size.x * 0.40, rect.size.y * 0.15))
	draw_rect(rect, Color(0.30, 0.12, 0.12, 0.36), true)
	draw_rect(rect.grow(-12.0), Color(0.48, 0.18, 0.18, 0.26), true)
	draw_rect(rect, Color(0.38, 0.14, 0.14, 0.55), false, 2.0)


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
	draw_rect(selection_rect, Color(0.35, 0.67, 0.98, 0.10), true)
	draw_rect(selection_rect, Color("#59aaf9"), false, 2.0)


func _draw_selected_paths() -> void:
	for unit_id in client_state.selected_entity_ids:
		if not game_state.entities.has(unit_id):
			continue
		var entity: Dictionary = game_state.get_entity_dict(unit_id)
		var path_cells: Array[Vector2i] = game_state.get_entity_path_cells(entity)
		if path_cells.is_empty():
			continue

		var points: PackedVector2Array = PackedVector2Array()
		points.append(_cell_center(game_state.get_entity_grid_position(entity)))
		for path_cell in path_cells:
			points.append(_cell_center(path_cell))

		var path_color: Color = Color(0.32, 0.80, 0.92, 0.65)
		var attack_move_target: Vector2i = _get_attack_move_target_cell(entity)
		if attack_move_target != Vector2i(-1, -1):
			path_color = Color(0.92, 0.42, 0.42, 0.65)
		draw_polyline(points, path_color, 3.0)
		if points.size() >= 2:
			_draw_arrowhead(points[points.size() - 1], path_color, 8.0)


func _draw_selected_attack_links() -> void:
	if client_state.selected_entity_ids.is_empty():
		return
	for unit_id in client_state.selected_entity_ids:
		if not game_state.entities.has(unit_id):
			continue
		var entity: Dictionary = game_state.get_entity_dict(unit_id)
		var target_id: int = game_state.get_entity_attack_target_id(entity)
		if target_id == 0 or not game_state.entities.has(target_id):
			continue
		var target_entity: Dictionary = game_state.get_entity_dict(target_id)
		var from_pos: Vector2 = client_state.get_visual_unit_world_position(unit_id, _cell_center(game_state.get_entity_grid_position(entity)))
		var to_pos: Vector2 = _cell_center(game_state.get_entity_grid_position(target_entity))
		draw_line(from_pos, to_pos, Color(attack_indicator_color.r, attack_indicator_color.g, attack_indicator_color.b, 0.6), 2.0)
		_draw_target_ring(to_pos, float(cell_size) * 0.18, attack_indicator_color)


func _draw_selected_producer_rally() -> void:
	if client_state.selected_entity_ids.size() != 1:
		return
	var selected_id: int = client_state.selected_entity_ids[0]
	if not game_state.entities.has(selected_id):
		return
	var entity: Dictionary = game_state.get_entity_dict(selected_id)
	var entity_type: String = game_state.get_entity_type(entity)
	if entity_type != "stockpile" and entity_type != "structure":
		return
	var rally_mode: String = game_state.get_entity_rally_mode(entity)
	if rally_mode == "":
		return
	var rally_cell: Vector2i = game_state.get_entity_rally_cell(entity)
	if rally_cell.x < 0 or rally_cell.y < 0:
		return
	var from_pos: Vector2 = _cell_center(game_state.get_entity_grid_position(entity))
	var to_pos: Vector2 = _cell_center(rally_cell)
	draw_line(from_pos, to_pos, Color(rally_color.r, rally_color.g, rally_color.b, 0.62), 3.0)
	_draw_arrowhead(to_pos, rally_color, 10.0)


func _draw_selected_attack_ranges() -> void:
	if client_state.selected_entity_ids.size() != 1:
		return
	var selected_id: int = client_state.selected_entity_ids[0]
	if not game_state.entities.has(selected_id):
		return
	var entity: Dictionary = game_state.get_entity_dict(selected_id)
	if not game_state.get_entity_can_attack(entity):
		return
	var attack_range: int = game_state.get_entity_attack_range_cells(entity)
	if attack_range <= 0:
		return
	var center: Vector2 = _cell_center(game_state.get_entity_grid_position(entity))
	var radius: float = float(cell_size * attack_range)
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius),
	])
	draw_polyline(points, Color(0.98, 0.86, 0.34, 0.38), 2.0)


func _draw_projectiles() -> void:
	for projectile in _projectiles:
		var elapsed: float = float(projectile.get("elapsed", 0.0))
		var duration: float = float(projectile.get("duration", PROJECTILE_DURATION))
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		var start: Vector2 = Vector2.ZERO
		var end: Vector2 = Vector2.ZERO
		var color: Color = Color.WHITE
		if projectile.get("start", null) is Vector2:
			start = projectile["start"]
		if projectile.get("end", null) is Vector2:
			end = projectile["end"]
		if projectile.get("color", null) is Color:
			color = projectile["color"]
		var current: Vector2 = start.lerp(end, eased)
		var previous: Vector2 = start.lerp(end, maxf(0.0, eased - 0.15))
		var texture_rect: Rect2 = Rect2(current - Vector2(14.0, 4.0), Vector2(28.0, 8.0))
		if not _draw_particle_texture("projectile", texture_rect, color):
			draw_line(previous, current, color, 3.0)
			draw_circle(current, 3.5, color.lightened(0.15))


func _draw_units() -> void:
	var entity_ids: Array = game_state.entities.keys()
	entity_ids.sort()
	for entity_id in entity_ids:
		var entity: Dictionary = game_state.get_entity_dict(entity_id)
		if game_state.get_entity_type(entity) != "unit":
			continue
		var owner_id: int = game_state.get_entity_owner_id(entity, 1)
		var authoritative_cell: Vector2i = game_state.get_entity_grid_position(entity)
		if owner_id != 1 and not _player_visible_cells.has(game_state.cell_key(authoritative_cell)):
			continue

		var authoritative_center: Vector2 = _cell_center(authoritative_cell)
		var visual_position: Vector2 = client_state.get_visual_unit_world_position(entity_id, authoritative_center)
		var unit_radius: float = float(cell_size) * 0.25
		var unit_role: String = game_state.get_entity_unit_role(entity)
		var fill_color: Color = _get_unit_fill_color(entity)
		var flash_alpha: float = _get_hit_flash_alpha(entity_id)
		fill_color = fill_color.lerp(Color.WHITE, flash_alpha * 0.65)
		var bob_offset: float = 0.0
		if game_state.get_entity_task_state(entity) == "idle":
			bob_offset = sin(_presentation_time * IDLE_BOB_SPEED + float(entity_id) * 0.73) * IDLE_BOB_AMPLITUDE
		visual_position.y += bob_offset

		_draw_shadow(visual_position + Vector2(0.0, unit_radius * 0.72), Vector2(unit_radius * 0.80, unit_radius * 0.32))
		var unit_rect: Rect2 = Rect2(
			visual_position - Vector2(unit_radius * 1.35, unit_radius * 1.95),
			Vector2(unit_radius * 2.70, unit_radius * 2.95)
		)
		var drew_unit_texture: bool = _draw_world_texture(_get_unit_texture_key(unit_role, owner_id), unit_rect, fill_color)
		if not drew_unit_texture:
			_draw_unit_shape(unit_role, visual_position, unit_radius, fill_color, owner_id)
		else:
			_draw_unit_role_glyph(unit_role, visual_position + Vector2(0.0, unit_radius * 0.10), unit_radius * 0.85)
		if not drew_unit_texture:
			_draw_unit_role_glyph(unit_role, visual_position, unit_radius)

		if unit_role == "worker" and game_state.get_entity_carried_amount(entity) > 0:
			draw_circle(visual_position + Vector2(unit_radius * 0.5, -unit_radius * 0.45), unit_radius * 0.22, Color("#b07d49"))

		if _should_draw_unit_hp_bar(entity, entity_id):
			_draw_unit_hp_bar(entity, visual_position, unit_radius)

		var show_authoritative: bool = client_state.selected_entity_ids.has(entity_id)
		show_authoritative = show_authoritative or client_state.hovered_entity_id == entity_id
		show_authoritative = show_authoritative or visual_position.distance_to(authoritative_center) > 5.0
		if show_authoritative:
			_draw_authoritative_marker(authoritative_center)

		var selector_center: Vector2 = visual_position + Vector2(0.0, unit_radius * 1.05)
		if client_state.hovered_entity_id == entity_id:
			draw_arc(selector_center, unit_radius + 3.0, 0.0, TAU, 40, Color(0.48, 0.87, 0.95, 0.72), 1.8)
		if client_state.selected_entity_ids.has(entity_id):
			var pulse: float = 1.0 + 0.06 * sin(_presentation_time * 4.0 + float(entity_id))
			draw_arc(selector_center, (unit_radius + 6.0) * pulse, 0.0, TAU, 40, Color(selected_color.r, selected_color.g, selected_color.b, 0.88), 2.4)


func _draw_unit_shape(unit_role: String, visual_position: Vector2, radius: float, fill_color: Color, owner_id: int) -> void:
	if unit_role == "worker":
		draw_circle(visual_position, radius * 0.88, fill_color)
		draw_circle(visual_position + Vector2(0.0, -radius * 0.15), radius * 0.40, fill_color.lightened(0.12))
	elif unit_role == "soldier":
		var body: PackedVector2Array = PackedVector2Array([
			visual_position + Vector2(0.0, -radius * 0.95),
			visual_position + Vector2(radius * 0.82, -radius * 0.12),
			visual_position + Vector2(radius * 0.48, radius * 0.88),
			visual_position + Vector2(-radius * 0.48, radius * 0.88),
			visual_position + Vector2(-radius * 0.82, -radius * 0.12),
		])
		draw_colored_polygon(body, fill_color)
	else:
		var body_tri: PackedVector2Array = PackedVector2Array([
			visual_position + Vector2(0.0, -radius * 0.95),
			visual_position + Vector2(radius * 0.88, radius * 0.75),
			visual_position + Vector2(-radius * 0.88, radius * 0.75),
		])
		draw_colored_polygon(body_tri, fill_color)

	draw_arc(visual_position, radius, 0.0, TAU, 48, Color("#0f1216"), 4.0)
	var accent: Color = unit_color if owner_id == 1 else enemy_unit_color
	draw_arc(visual_position, radius - 7.0, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.65), 2.0)


func _draw_unit_role_glyph(unit_role: String, visual_position: Vector2, radius: float) -> void:
	if unit_role == "worker":
		draw_line(visual_position + Vector2(radius * 0.20, -radius * 0.55), visual_position + Vector2(radius * 0.40, radius * 0.35), Color("#4e342e"), 3.0)
		draw_line(visual_position + Vector2(radius * 0.08, -radius * 0.18), visual_position + Vector2(radius * 0.52, -radius * 0.32), Color("#d7ccc8"), 2.0)
	elif unit_role == "soldier":
		draw_line(visual_position + Vector2(0.0, -radius * 0.60), visual_position + Vector2(0.0, radius * 0.42), Color("#ffecd1"), 3.0)
		draw_line(visual_position + Vector2(-radius * 0.28, -radius * 0.14), visual_position + Vector2(radius * 0.28, -radius * 0.14), Color("#ffecd1"), 2.0)
	else:
		draw_arc(visual_position + Vector2(-radius * 0.10, 0.0), radius * 0.42, -PI * 0.5, PI * 0.5, 16, Color("#e0f7fa"), 3.0)
		draw_line(visual_position + Vector2(-radius * 0.10, -radius * 0.42), visual_position + Vector2(-radius * 0.10, radius * 0.42), Color("#e0f7fa"), 2.0)


func _draw_unit_hp_bar(entity: Dictionary, visual_position: Vector2, unit_radius: float) -> void:
	var max_hp: int = maxi(game_state.get_entity_max_hp(entity), 1)
	var hp: int = game_state.get_entity_hp(entity)
	var hp_ratio: float = float(hp) / float(max_hp)
	var bar_width: float = unit_radius * 1.9
	var bar_rect: Rect2 = Rect2(
		visual_position.x - unit_radius,
		visual_position.y + unit_radius + 6.0,
		bar_width,
		4.0
	)
	draw_rect(bar_rect, Color(0.08, 0.08, 0.10, 0.88), true)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), _hp_bar_color(hp_ratio), true)


func _draw_authoritative_marker(center: Vector2) -> void:
	var half_size: float = float(cell_size) * 0.05
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -half_size),
		center + Vector2(half_size, 0.0),
		center + Vector2(0.0, half_size),
		center + Vector2(-half_size, 0.0),
	])
	draw_colored_polygon(diamond, Color(authoritative_cell_color.r, authoritative_cell_color.g, authoritative_cell_color.b, 0.82))
	draw_polyline(_closed_polyline(diamond), Color(1.0, 1.0, 1.0, 0.72), 1.0)


func _draw_completion_pulses() -> void:
	for pulse in _completion_pulses:
		var center: Vector2 = Vector2.ZERO
		var color: Color = selected_color
		if pulse.get("center", null) is Vector2:
			center = pulse["center"]
		if pulse.get("color", null) is Color:
			color = pulse["color"]
		var elapsed: float = float(pulse.get("elapsed", 0.0))
		var duration: float = float(pulse.get("duration", COMPLETION_PULSE_DURATION))
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		var radius: float = lerpf(float(cell_size) * 0.20, float(cell_size) * 0.72, t)
		var alpha: float = 1.0 - t
		var pulse_rect: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		if not _draw_particle_texture("completion", pulse_rect, Color(color.r, color.g, color.b, alpha * 0.72)):
			draw_arc(center, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, alpha * 0.72), 3.0)


func _draw_impact_markers() -> void:
	for marker in _impact_markers:
		var center: Vector2 = Vector2.ZERO
		var color: Color = attack_indicator_color
		if marker.get("center", null) is Vector2:
			center = marker["center"]
		if marker.get("color", null) is Color:
			color = marker["color"]
		var elapsed: float = float(marker.get("elapsed", 0.0))
		var duration: float = float(marker.get("duration", IMPACT_DURATION))
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		var radius: float = lerpf(4.0, float(cell_size) * 0.26, t)
		var alpha: float = 1.0 - t
		var impact_rect: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		if not _draw_particle_texture("impact", impact_rect, Color(color.r, color.g, color.b, alpha * 0.92)):
			draw_arc(center, radius, 0.0, TAU, 18, Color(color.r, color.g, color.b, alpha * 0.80), 2.0)
			draw_line(center + Vector2(-radius * 0.5, 0.0), center + Vector2(radius * 0.5, 0.0), Color(color.r, color.g, color.b, alpha), 2.0)
			draw_line(center + Vector2(0.0, -radius * 0.5), center + Vector2(0.0, radius * 0.5), Color(color.r, color.g, color.b, alpha), 2.0)


func _draw_shadow(center: Vector2, size: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(14):
		var angle: float = (TAU * float(index)) / 14.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, shadow_color)


func _draw_target_ring(center: Vector2, radius: float, color: Color) -> void:
	draw_arc(center, radius, 0.0, TAU, 24, color, 3.0)
	draw_arc(center, radius + 6.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.22), 1.5)


func _draw_arrowhead(center: Vector2, color: Color, size: float) -> void:
	var tri: PackedVector2Array = PackedVector2Array([
		center + Vector2(size * 0.55, 0.0),
		center + Vector2(-size * 0.35, -size * 0.35),
		center + Vector2(-size * 0.35, size * 0.35),
	])
	draw_colored_polygon(tri, color)


func _draw_scaffold_lines(rect: Rect2, color: Color) -> void:
	var step: float = 10.0
	var x: float = rect.position.x - rect.size.y
	while x < rect.position.x + rect.size.x:
		draw_line(
			Vector2(x, rect.position.y + rect.size.y),
			Vector2(x + rect.size.y, rect.position.y),
			color,
			1.5
		)
		x += step


func _should_draw_structure_bars(entity: Dictionary) -> bool:
	var entity_id: int = game_state.get_entity_id(entity)
	if client_state.selected_entity_ids.has(entity_id):
		return true
	if client_state.hovered_entity_id == entity_id:
		return true
	if game_state.get_entity_hp(entity) < game_state.get_entity_max_hp(entity):
		return true
	return not game_state.get_entity_is_constructed(entity)


func _should_draw_unit_hp_bar(entity: Dictionary, entity_id: int) -> bool:
	if client_state.selected_entity_ids.has(entity_id):
		return true
	if client_state.hovered_entity_id == entity_id:
		return true
	if game_state.get_entity_hp(entity) < game_state.get_entity_max_hp(entity):
		return true
	return _hit_flash_timers.has(entity_id)


func _get_hit_flash_alpha(entity_id: int) -> float:
	if not _hit_flash_timers.has(entity_id):
		return 0.0
	var remaining: float = float(_hit_flash_timers[entity_id])
	return clampf(remaining / HIT_FLASH_DURATION, 0.0, 1.0)


func _get_unit_fill_color(entity: Dictionary) -> Color:
	var unit_role: String = game_state.get_entity_unit_role(entity)
	var owner_id: int = game_state.get_entity_owner_id(entity, 1)
	if owner_id != 1:
		return enemy_unit_color
	if unit_role == "soldier":
		return soldier_color
	if unit_role == "archer":
		return archer_color
	return unit_color


func _get_resource_texture_key(resource_type: String, cell: Vector2i) -> String:
	if resource_type == "stone":
		return "stone_node_large" if _cell_noise(cell) > 0.45 else "stone_node_small"
	return "tree_cluster_round" if _region_noise(cell, 2) > 0.45 else "pine_cluster"


func _get_attack_move_target_cell(entity: Dictionary) -> Vector2i:
	if entity.has("attack_move_target_cell"):
		var cell_value: Variant = entity["attack_move_target_cell"]
		if cell_value is Vector2i:
			return cell_value
	return Vector2i(-1, -1)


func _get_structure_texture_key(structure_type: String, is_stockpile: bool, owner_id: int) -> String:
	if owner_id != 1 and structure_type == "enemy_base":
		return "enemy_base"
	if is_stockpile or structure_type == "stockpile":
		return "stockpile"
	if _world_textures.has(structure_type):
		return structure_type
	if owner_id != 1:
		return "enemy_base"
	return ""


func _get_unit_texture_key(unit_role: String, owner_id: int) -> String:
	if owner_id != 1:
		return "enemy_unit"
	if _world_textures.has(unit_role):
		return unit_role
	return ""


func _draw_world_texture(key: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	if key == "" or not _world_textures.has(key):
		return false
	var texture_value: Variant = _world_textures[key]
	if not (texture_value is Texture2D):
		return false
	var texture: Texture2D = texture_value
	draw_texture_rect(texture, rect, false, modulate)
	return true


func _draw_particle_texture(key: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	if key == "" or not _particle_textures.has(key):
		return false
	var texture_value: Variant = _particle_textures[key]
	if not (texture_value is Texture2D):
		return false
	var texture: Texture2D = texture_value
	draw_texture_rect(texture, rect, false, modulate)
	return true


func _hp_bar_color(hp_ratio: float) -> Color:
	if hp_ratio > 0.5:
		return Color("#59cd90")
	if hp_ratio > 0.25:
		return Color("#f4d35e")
	return Color("#e63946")


func _cell_noise(cell: Vector2i) -> float:
	var hashed: int = absi(cell.x * 92821 + cell.y * 68917 + cell.x * cell.y * 17) % 100
	return float(hashed) / 100.0


func _region_noise(cell: Vector2i, scale: int) -> float:
	var coarse: Vector2i = Vector2i(floori(float(cell.x) / float(scale)), floori(float(cell.y) / float(scale)))
	var hashed: int = absi(coarse.x * 73471 + coarse.y * 19391 + coarse.x * coarse.y * 29) % 100
	return float(hashed) / 100.0


func _cell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * cell_size,
		(cell.y + 0.5) * cell_size
	)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size, cell.y * cell_size),
		Vector2(cell_size, cell_size)
	)


func _closed_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = PackedVector2Array()
	for point in points:
		closed.append(point)
	if points.size() > 0:
		closed.append(points[0])
	return closed
