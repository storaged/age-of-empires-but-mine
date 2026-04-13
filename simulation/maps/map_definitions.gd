class_name MapDefinitions
extends RefCounted

const DEFAULT_MAP_ID: String = "valley_hold"

const MAPS: Dictionary = {
	"valley_hold": {
		"display_name": "Valley Hold",
		"summary": "Open valley with split stone and a central ridge.",
		"map_width": 20,
		"map_height": 14,
		"blocked_cells": [
			Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
			Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6),
			Vector2i(12, 6), Vector2i(12, 5), Vector2i(12, 4),
			Vector2i(13, 9), Vector2i(15, 4), Vector2i(15, 5),
			Vector2i(5, 11), Vector2i(6, 11),
		],
		"resource_nodes": [
			{"type": "wood", "cell": Vector2i(14, 4), "amount": 90},
			{"type": "wood", "cell": Vector2i(14, 5), "amount": 90},
			{"type": "stone", "cell": Vector2i(5, 11), "amount": 70},
			{"type": "stone", "cell": Vector2i(6, 11), "amount": 70},
		],
	},
	"split_ridge": {
		"display_name": "Split Ridge",
		"summary": "Long broken ridge with safer backline economy.",
		"map_width": 22,
		"map_height": 15,
		"blocked_cells": [
			Vector2i(9, 2), Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
			Vector2i(9, 6), Vector2i(9, 7), Vector2i(12, 7), Vector2i(13, 7),
			Vector2i(14, 7), Vector2i(15, 7), Vector2i(16, 7), Vector2i(12, 10),
			Vector2i(13, 10), Vector2i(14, 10),
		],
		"resource_nodes": [
			{"type": "wood", "cell": Vector2i(6, 9), "amount": 90},
			{"type": "wood", "cell": Vector2i(7, 9), "amount": 90},
			{"type": "stone", "cell": Vector2i(14, 12), "amount": 70},
			{"type": "stone", "cell": Vector2i(15, 12), "amount": 70},
		],
	},
	"knife_pass": {
		"display_name": "Knife Pass",
		"summary": "Tight central pass with exposed food timing.",
		"map_width": 18,
		"map_height": 13,
		"blocked_cells": [
			Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 5),
			Vector2i(7, 6), Vector2i(7, 7), Vector2i(10, 4), Vector2i(10, 5),
			Vector2i(10, 6), Vector2i(10, 8), Vector2i(10, 9), Vector2i(10, 10),
			Vector2i(8, 4), Vector2i(9, 4), Vector2i(8, 8), Vector2i(9, 8),
		],
		"resource_nodes": [
			{"type": "wood", "cell": Vector2i(4, 9), "amount": 75},
			{"type": "wood", "cell": Vector2i(5, 9), "amount": 75},
			{"type": "stone", "cell": Vector2i(13, 2), "amount": 65},
			{"type": "stone", "cell": Vector2i(13, 3), "amount": 65},
		],
	},
}


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for map_id in MAPS.keys():
		if map_id is String:
			ids.append(map_id)
	ids.sort()
	return ids


static func get_map(map_id: String) -> Dictionary:
	if not MAPS.has(map_id):
		return MAPS[DEFAULT_MAP_ID].duplicate(true)
	var map_value: Variant = MAPS[map_id]
	if map_value is Dictionary:
		return map_value.duplicate(true)
	return MAPS[DEFAULT_MAP_ID].duplicate(true)


static func get_display_name(map_id: String) -> String:
	var definition: Dictionary = get_map(map_id)
	return str(definition.get("display_name", map_id))
