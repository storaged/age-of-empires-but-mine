class_name AssetCatalog
extends RefCounted

const MedievalAliasesClass = preload("res://rendering/asset_aliases_medieval_rts.gd")

const ROOT_MEDIEVAL: String = "res://assets/third_party/kenney/kenney_medieval-rts/PNG/Default size"
const ROOT_PARTICLES: String = "res://assets/third_party/kenney/kenney_particle-pack/PNG (Transparent)"
const ROOT_UI: String = "res://assets/third_party/kenney/kenney_ui-pack"
const ROOT_UI_AUDIO: String = "res://assets/third_party/kenney/kenney_ui-audio/Audio"

const PANEL_TEXTURES: Dictionary = {
	"blue": ROOT_UI + "/PNG/Blue/Default/button_rectangle_depth_gloss.png",
	"green": ROOT_UI + "/PNG/Green/Default/button_rectangle_depth_gloss.png",
}
const BUTTON_TEXTURES: Dictionary = {
	"normal": ROOT_UI + "/PNG/Blue/Default/button_rectangle_depth_gloss.png",
	"hover": ROOT_UI + "/PNG/Green/Default/button_rectangle_depth_gloss.png",
	"pressed": ROOT_UI + "/PNG/Blue/Default/button_rectangle_depth_border.png",
	"disabled": ROOT_UI + "/PNG/Blue/Default/button_rectangle_flat.png",
}
const FONT_PATH: String = ROOT_UI + "/Font/Kenney Future Narrow.ttf"
const UI_AUDIO: Dictionary = {
	"click": ROOT_UI_AUDIO + "/click1.ogg",
	"hover": ROOT_UI_AUDIO + "/rollover1.ogg",
	"alert": ROOT_UI_AUDIO + "/switch23.ogg",
}
const PARTICLE_TEXTURES: Dictionary = {
	"impact": ROOT_PARTICLES + "/spark_05.png",
	"completion": ROOT_PARTICLES + "/star_05.png",
	"projectile": ROOT_PARTICLES + "/trace_03.png",
	"dust": ROOT_PARTICLES + "/dirt_02.png",
}
static var _resource_cache: Dictionary = {}


static func get_world_texture(key: String) -> Texture2D:
	return _load_texture(str(_get_world_texture_paths().get(key, "")))


static func get_particle_texture(key: String) -> Texture2D:
	return _load_texture(str(PARTICLE_TEXTURES.get(key, "")))


static func get_audio_stream(key: String) -> AudioStream:
	return _load_stream(str(UI_AUDIO.get(key, "")))


static func get_font() -> FontFile:
	var resource: Resource = _load_resource(FONT_PATH)
	if resource is FontFile:
		return resource
	return null


static func make_panel_style(color_key: String = "blue") -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(str(PANEL_TEXTURES.get(color_key, "")))
	if texture == null:
		return null
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = texture
	style_box.texture_margin_left = 12.0
	style_box.texture_margin_top = 12.0
	style_box.texture_margin_right = 12.0
	style_box.texture_margin_bottom = 12.0
	style_box.content_margin_left = 10.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_right = 10.0
	style_box.content_margin_bottom = 8.0
	return style_box


static func make_button_style(kind: String) -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(str(BUTTON_TEXTURES.get(kind, "")))
	if texture == null:
		return null
	var style_box: StyleBoxTexture = StyleBoxTexture.new()
	style_box.texture = texture
	style_box.texture_margin_left = 12.0
	style_box.texture_margin_top = 12.0
	style_box.texture_margin_right = 12.0
	style_box.texture_margin_bottom = 12.0
	style_box.content_margin_left = 10.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_right = 10.0
	style_box.content_margin_bottom = 8.0
	return style_box


static func _load_texture(path: String) -> Texture2D:
	var resource: Resource = _load_resource(path)
	if resource is Texture2D:
		return resource
	return null


static func _load_stream(path: String) -> AudioStream:
	var resource: Resource = _load_resource(path)
	if resource is AudioStream:
		return resource
	return null


static func _load_resource(path: String) -> Resource:
	if path == "":
		return null
	if _resource_cache.has(path):
		var cached: Variant = _resource_cache[path]
		if cached is Resource:
			return cached
		return null
	if not ResourceLoader.exists(path):
		_resource_cache[path] = null
		return null
	var resource: Resource = load(path)
	_resource_cache[path] = resource
	return resource


static func _get_world_texture_paths() -> Dictionary:
	return {
		"grass_base_a": _tile_alias_path("grass_base_a"),
		"grass_base_b": _tile_alias_path("grass_base_b"),
		"sand_base_a": _tile_alias_path("sand_base_a"),
		"sand_base_b": _tile_alias_path("sand_base_b"),
		"dirt_base_a": _tile_alias_path("dirt_base_a"),
		"dirt_base_b": _tile_alias_path("dirt_base_b"),
		"stone_base_a": _tile_alias_path("stone_base_a"),
		"stone_base_b": _tile_alias_path("stone_base_b"),
		"road_full_straight_v": _tile_alias_path("road_full_straight_v"),
		"road_full_straight_h": _tile_alias_path("road_full_straight_h"),
		"road_full_cross": _tile_alias_path("road_full_cross"),
		"road_overlay_v": _tile_alias_path("road_overlay_v"),
		"road_overlay_h": _tile_alias_path("road_overlay_h"),
		"road_overlay_cross": _tile_alias_path("road_overlay_cross"),
		"tree_single_round": _tile_alias_path("tree_single_round"),
		"tree_cluster_round": _tile_alias_path("tree_cluster_round"),
		"pine_single": _tile_alias_path("pine_single"),
		"pine_cluster": _tile_alias_path("pine_cluster"),
		"stone_node_small": _tile_alias_path("stone_node_small"),
		"stone_node_large": _tile_alias_path("stone_node_large"),
		"farm_small_brown": _tile_alias_path("farm_small_brown"),
		"farm_small_light": _tile_alias_path("farm_small_light"),
		"farm_large_brown": _tile_alias_path("farm_large_brown"),
		"farm_large_light": _tile_alias_path("farm_large_light"),
		"obstacle": _tile_alias_path("pine_cluster"),
		"wood": _tile_alias_path("tree_cluster_round"),
		"stone": _tile_alias_path("stone_node_large"),
		"stockpile": _tile_alias_path("stockpile_storage"),
		"house": _tile_alias_path("house_small_green"),
		"farm": _tile_alias_path("windmill"),
		"barracks": ROOT_MEDIEVAL + "/Structure/medievalStructure_11.png",
		"archery_range": ROOT_MEDIEVAL + "/Structure/medievalStructure_14.png",
		"enemy_base": _tile_alias_path("fortress_enemy_base"),
		"worker": ROOT_MEDIEVAL + "/Unit/medievalUnit_01.png",
		"soldier": ROOT_MEDIEVAL + "/Unit/medievalUnit_05.png",
		"archer": ROOT_MEDIEVAL + "/Unit/medievalUnit_11.png",
		"enemy_unit": ROOT_MEDIEVAL + "/Unit/medievalUnit_21.png",
	}


static func _tile_alias_path(alias_key: String) -> String:
	if MedievalAliasesClass.TILE_ALIASES.has(alias_key):
		var file_name_value: Variant = MedievalAliasesClass.TILE_ALIASES[alias_key]
		if file_name_value is String:
			var file_name: String = file_name_value
			if file_name.begins_with("medievalTile_"):
				return ROOT_MEDIEVAL + "/Tile/" + file_name
			if file_name.begins_with("medievalEnvironment_"):
				return ROOT_MEDIEVAL + "/Environment/" + file_name
			if file_name.begins_with("medievalStructure_"):
				return ROOT_MEDIEVAL + "/Structure/" + file_name
	return ""
