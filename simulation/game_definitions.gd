class_name GameDefinitions
extends RefCounted

## Central content definitions — single source of truth for costs, durations,
## spawn templates, display names, prerequisites, and production relationships.
## Add new building/unit types here only. No content lives in individual systems.

## Building definitions.
## costs: Dictionary of {resource_type: amount} required to place.
## requires_building: structure_type that must be fully constructed first ("" = none).
## produces: unit_type this building trains, or "" if none.
const BUILDINGS: Dictionary = {
	"house": {
		"display_name": "House",
		"costs": {"wood": 30},
		"construction_duration": 24,
		"supply_provided": 5,
		"requires_building": "",
		"produces": "",
		"render_base": "#a56b3a",
		"render_inner": "#d4a373",
		"render_border": "#3b2413",
	},
	"barracks": {
		"display_name": "Barracks",
		"costs": {"wood": 40},
		"construction_duration": 30,
		"supply_provided": 0,
		"requires_building": "house",
		"produces": "soldier",
		"render_base": "#4a4e69",
		"render_inner": "#9a8c98",
		"render_border": "#22223b",
	},
	"archery_range": {
		"display_name": "Archery Range",
		"costs": {"wood": 25, "stone": 20},
		"construction_duration": 35,
		"supply_provided": 0,
		"requires_building": "barracks",
		"produces": "archer",
		"render_base": "#1a6b5a",
		"render_inner": "#4ecdc4",
		"render_border": "#0d3b31",
	},
}

## Unit definitions.
## production_costs: Dictionary of {resource_type: amount} to train this unit.
## unit_role: stored on entity, also used by systems to identify role.
const UNITS: Dictionary = {
	"worker": {
		"display_name": "Worker",
		"production_costs": {"wood": 20},
		"production_duration": 18,
		"population_cost": 1,
		"unit_role": "worker",
		"carry_capacity": 10,
		"harvest_amount": 5,
		"gather_duration_ticks": 8,
		"deposit_duration_ticks": 2,
	},
	"soldier": {
		"display_name": "Soldier",
		"production_costs": {"wood": 20},
		"production_duration": 15,
		"population_cost": 1,
		"unit_role": "soldier",
		"hp": 30,
		"max_hp": 30,
		"attack_damage": 8,
		"attack_cooldown_ticks": 4,
	},
	"archer": {
		"display_name": "Archer",
		"production_costs": {"wood": 15, "stone": 10},
		"production_duration": 20,
		"population_cost": 1,
		"unit_role": "archer",
		"hp": 20,
		"max_hp": 20,
		"attack_damage": 5,
		"attack_cooldown_ticks": 5,
	},
}

## Unit type produced by the stockpile (player base).
const STOCKPILE_PRODUCES: String = "worker"
const BASE_POPULATION_CAP: int = 5


## Returns full cost dictionary for a building: {"wood": N, "stone": M, ...}
static func get_building_costs(building_type: String) -> Dictionary:
	var def: Dictionary = _get_building_def(building_type)
	var costs_value: Variant = def.get("costs", {})
	if costs_value is Dictionary:
		return costs_value
	return {}


## Shorthand: wood cost only. Returns 0 if none.
static func get_building_cost(building_type: String) -> int:
	var costs: Dictionary = get_building_costs(building_type)
	var wood_value: Variant = costs.get("wood", 0)
	return wood_value if wood_value is int else 0


static func get_building_construction_duration(building_type: String) -> int:
	var def: Dictionary = _get_building_def(building_type)
	return _get_int(def, "construction_duration", 0)


static func get_building_display_name(building_type: String) -> String:
	var def: Dictionary = _get_building_def(building_type)
	return _get_string(def, "display_name", building_type.capitalize())


## Returns the building type that must be fully constructed before this can be placed.
## Empty string means no prerequisite.
static func get_building_prerequisite(building_type: String) -> String:
	var def: Dictionary = _get_building_def(building_type)
	return _get_string(def, "requires_building", "")


## Returns the unit_type this building produces, or "" if none.
static func get_building_produces(building_type: String) -> String:
	var def: Dictionary = _get_building_def(building_type)
	return _get_string(def, "produces", "")


static func get_stockpile_produces() -> String:
	return STOCKPILE_PRODUCES


static func get_base_population_cap() -> int:
	return BASE_POPULATION_CAP


## Returns full production cost dictionary for a unit: {"wood": N, ...}
static func get_unit_production_costs(unit_type: String) -> Dictionary:
	var def: Dictionary = _get_unit_def(unit_type)
	var costs_value: Variant = def.get("production_costs", {})
	if costs_value is Dictionary:
		return costs_value
	return {}


## Shorthand: wood production cost only. Returns 0 if none.
static func get_unit_production_cost(unit_type: String) -> int:
	var costs: Dictionary = get_unit_production_costs(unit_type)
	var wood_value: Variant = costs.get("wood", 0)
	return wood_value if wood_value is int else 0


static func get_unit_production_duration(unit_type: String) -> int:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_int(def, "production_duration", 0)


static func get_unit_display_name(unit_type: String) -> String:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_string(def, "display_name", unit_type.capitalize())


static func get_building_supply_provided(building_type: String) -> int:
	var def: Dictionary = _get_building_def(building_type)
	return _get_int(def, "supply_provided", 0)


static func get_unit_population_cost(unit_type: String) -> int:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_int(def, "population_cost", 0)


static func is_known_building_type(building_type: String) -> bool:
	return BUILDINGS.has(building_type)


static func is_known_unit_type(unit_type: String) -> bool:
	return UNITS.has(unit_type)


## Build a complete entity dictionary for a newly spawned unit.
## producer_id is stored as assigned_stockpile_id for workers.
static func create_unit_entity(
	unit_type: String,
	unit_id: int,
	owner_id: int,
	spawn_cell: Vector2i,
	producer_id: int
) -> Dictionary:
	var def: Dictionary = _get_unit_def(unit_type)
	if def.is_empty():
		return {}

	var role: String = _get_string(def, "unit_role", unit_type)
	var entity: Dictionary = {
		"id": unit_id,
		"entity_type": "unit",
		"unit_role": role,
		"owner_id": owner_id,
		"grid_position": spawn_cell,
		"move_target": spawn_cell,
		"path_cells": [],
		"has_move_target": false,
		"worker_task_state": "idle",
		"interaction_slot_cell": Vector2i(-1, -1),
		"traffic_state": "",
	}

	if role == "worker":
		entity["assigned_resource_node_id"] = 0
		entity["assigned_stockpile_id"] = producer_id
		entity["assigned_construction_site_id"] = 0
		entity["carried_resource_type"] = ""
		entity["carried_amount"] = 0
		entity["carry_capacity"] = _get_int(def, "carry_capacity", 10)
		entity["harvest_amount"] = _get_int(def, "harvest_amount", 5)
		entity["gather_duration_ticks"] = _get_int(def, "gather_duration_ticks", 8)
		entity["deposit_duration_ticks"] = _get_int(def, "deposit_duration_ticks", 2)
		entity["gather_progress_ticks"] = 0
	elif role == "soldier" or role == "archer":
		entity["hp"] = _get_int(def, "hp", 20)
		entity["max_hp"] = _get_int(def, "max_hp", 20)
		entity["attack_target_id"] = 0
		entity["attack_cooldown_remaining"] = 0
		entity["attack_damage"] = _get_int(def, "attack_damage", 5)
		entity["attack_cooldown_ticks"] = _get_int(def, "attack_cooldown_ticks", 5)

	return entity


## Compact cost string. Examples: "30W", "25W 20S".
static func format_costs_short(costs: Dictionary) -> String:
	if costs.is_empty():
		return "free"
	var abbreviations: Dictionary = {"wood": "W", "stone": "S"}
	var keys: Array = costs.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var val: Variant = costs[key]
		var amount: int = val if val is int else 0
		if amount > 0:
			var abbr: String
			if abbreviations.has(key):
				abbr = str(abbreviations[key])
			else:
				abbr = (str(key) as String).left(1).to_upper()
			parts.append("%d%s" % [amount, abbr])
	return " ".join(parts)


## Returns Color dict for a player-owned building: {"base": Color, "inner": Color, "border": Color}.
## Empty dict if type unknown.
static func get_building_render_colors(building_type: String) -> Dictionary:
	var def: Dictionary = _get_building_def(building_type)
	if def.is_empty():
		return {}
	return {
		"base": Color(_get_string(def, "render_base", "#808080")),
		"inner": Color(_get_string(def, "render_inner", "#aaaaaa")),
		"border": Color(_get_string(def, "render_border", "#404040")),
	}


## Format a costs dictionary as a human-readable string: "25 wood, 20 stone"
static func format_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "free"
	var keys: Array = costs.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var val: Variant = costs[key]
		var amount: int = val if val is int else 0
		if amount > 0:
			parts.append("%d %s" % [amount, str(key)])
	return ", ".join(parts)


static func _get_building_def(building_type: String) -> Dictionary:
	if not BUILDINGS.has(building_type):
		return {}
	var value: Variant = BUILDINGS[building_type]
	if value is Dictionary:
		return value
	return {}


static func _get_unit_def(unit_type: String) -> Dictionary:
	if not UNITS.has(unit_type):
		return {}
	var value: Variant = UNITS[unit_type]
	if value is Dictionary:
		return value
	return {}


static func _get_string(d: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = d.get(key, fallback)
	if value is String:
		return value
	return fallback


static func _get_int(d: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = d.get(key, fallback)
	if value is int:
		return value
	return fallback
