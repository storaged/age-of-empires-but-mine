class_name ColorPresets
extends RefCounted

const DEFAULT_COLOR_PRESET_ID: String = "classic"

const PRESETS: Dictionary = {
	"classic": {
		"display_name": "Classic",
		"player_unit_color": Color("#d6d2c4"),
		"player_soldier_color": Color("#4a7fc1"),
		"player_archer_color": Color("#2ec4b6"),
		"player_stockpile_color": Color("#3a6ea5"),
		"enemy_unit_color": Color("#e84a1e"),
		"enemy_structure_color": Color("#c93a1a"),
	},
	"emerald_vs_ember": {
		"display_name": "Emerald vs Ember",
		"player_unit_color": Color("#d2f4ea"),
		"player_soldier_color": Color("#2a9d8f"),
		"player_archer_color": Color("#52b788"),
		"player_stockpile_color": Color("#1f6f63"),
		"enemy_unit_color": Color("#ff7b54"),
		"enemy_structure_color": Color("#d6451b"),
	},
	"sand_vs_ink": {
		"display_name": "Sand vs Ink",
		"player_unit_color": Color("#f2e8cf"),
		"player_soldier_color": Color("#bc8a5f"),
		"player_archer_color": Color("#ddb892"),
		"player_stockpile_color": Color("#8d6e63"),
		"enemy_unit_color": Color("#344e41"),
		"enemy_structure_color": Color("#1b4332"),
	},
}


static func get_ids() -> Array[String]:
	var preset_ids: Array[String] = []
	for preset_id in PRESETS.keys():
		if preset_id is String:
			preset_ids.append(preset_id)
	preset_ids.sort()
	return preset_ids


static func get_display_name(preset_id: String) -> String:
	var preset: Dictionary = get_preset(preset_id)
	return str(preset.get("display_name", preset_id))


static func get_preset(preset_id: String) -> Dictionary:
	if not PRESETS.has(preset_id):
		return PRESETS[DEFAULT_COLOR_PRESET_ID]
	var preset_value: Variant = PRESETS[preset_id]
	if preset_value is Dictionary:
		return preset_value.duplicate(true)
	return PRESETS[DEFAULT_COLOR_PRESET_ID].duplicate(true)
