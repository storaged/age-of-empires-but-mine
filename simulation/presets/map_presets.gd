class_name MapPresets
extends RefCounted

const DEFAULT_MAP_PRESET_ID: String = "classic_valley"

const PRESETS: Dictionary = {
	"classic_valley": {
		"display_name": "Classic Valley",
		"map_width": 20,
		"map_height": 14,
		"blocked_cells": [
			Vector2i(8, 4),
			Vector2i(8, 5),
			Vector2i(8, 6),
			Vector2i(9, 6),
			Vector2i(10, 6),
			Vector2i(11, 6),
			Vector2i(12, 6),
			Vector2i(12, 5),
			Vector2i(12, 4),
			Vector2i(13, 9),
			Vector2i(15, 4),
			Vector2i(15, 5),
			Vector2i(5, 11),
			Vector2i(6, 11),
		],
		"player_stockpile_cell": Vector2i(2, 2),
		"player_worker_cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],
		"enemy_base_cell": Vector2i(17, 8),
		"enemy_producer_type": "barracks",
		"enemy_producer_cell": Vector2i(15, 9),
		"enemy_unit_cells": [Vector2i(15, 8), Vector2i(16, 10)],
		"resource_nodes": [
			{"type": "wood", "cell": Vector2i(15, 4), "amount": 80},
			{"type": "wood", "cell": Vector2i(15, 5), "amount": 80},
			{"type": "stone", "cell": Vector2i(5, 11), "amount": 60},
			{"type": "stone", "cell": Vector2i(6, 11), "amount": 60},
		],
	},
	"split_ridge": {
		"display_name": "Split Ridge",
		"map_width": 22,
		"map_height": 15,
		"blocked_cells": [
			Vector2i(9, 2),
			Vector2i(9, 3),
			Vector2i(9, 4),
			Vector2i(9, 5),
			Vector2i(9, 6),
			Vector2i(9, 7),
			Vector2i(12, 7),
			Vector2i(13, 7),
			Vector2i(14, 7),
			Vector2i(15, 7),
			Vector2i(16, 7),
			Vector2i(12, 10),
			Vector2i(13, 10),
			Vector2i(14, 10),
		],
		"player_stockpile_cell": Vector2i(3, 11),
		"player_worker_cells": [Vector2i(4, 11), Vector2i(4, 12), Vector2i(3, 12), Vector2i(5, 11)],
		"enemy_base_cell": Vector2i(18, 3),
		"enemy_producer_type": "barracks",
		"enemy_producer_cell": Vector2i(17, 5),
		"enemy_unit_cells": [Vector2i(18, 5), Vector2i(19, 5)],
		"resource_nodes": [
			{"type": "wood", "cell": Vector2i(6, 9), "amount": 80},
			{"type": "wood", "cell": Vector2i(7, 9), "amount": 80},
			{"type": "stone", "cell": Vector2i(14, 12), "amount": 60},
			{"type": "stone", "cell": Vector2i(15, 12), "amount": 60},
		],
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
		return PRESETS[DEFAULT_MAP_PRESET_ID]
	var preset_value: Variant = PRESETS[preset_id]
	if preset_value is Dictionary:
		return preset_value.duplicate(true)
	return PRESETS[DEFAULT_MAP_PRESET_ID].duplicate(true)
