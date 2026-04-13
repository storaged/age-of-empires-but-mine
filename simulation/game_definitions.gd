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
		"hp": 45,
		"max_hp": 45,
		"requires_building": "",
		"produces": "",
		"vision_radius_cells": 2,
		"render_base": "#a56b3a",
		"render_inner": "#d4a373",
		"render_border": "#3b2413",
	},
	"farm": {
		"display_name": "Farm",
		"costs": {"wood": 35},
		"construction_duration": 22,
		"supply_provided": 0,
		"hp": 35,
		"max_hp": 35,
		"requires_building": "house",
		"produces": "",
		"resource_trickle_type": "food",
		"resource_trickle_amount": 2,
		"resource_trickle_interval_ticks": 8,
		"vision_radius_cells": 2,
		"render_base": "#466b2d",
		"render_inner": "#8cbf45",
		"render_border": "#223316",
	},
	"barracks": {
		"display_name": "Barracks",
		"costs": {"wood": 40},
		"construction_duration": 30,
		"supply_provided": 0,
		"hp": 45,
		"max_hp": 45,
		"requires_building": "house",
		"produces": "soldier",
		"vision_radius_cells": 3,
		"render_base": "#4a4e69",
		"render_inner": "#9a8c98",
		"render_border": "#22223b",
	},
	"archery_range": {
		"display_name": "Archery Range",
		"costs": {"wood": 25, "stone": 20},
		"construction_duration": 35,
		"supply_provided": 0,
		"hp": 45,
		"max_hp": 45,
		"requires_building": "barracks",
		"produces": "archer",
		"vision_radius_cells": 3,
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
		"hp": 18,
		"max_hp": 18,
		"attack_damage": 0,
		"attack_range_cells": 0,
		"attack_cooldown_ticks": 0,
		"carry_capacity": 10,
		"harvest_amount": 5,
		"gather_duration_ticks": 8,
		"deposit_duration_ticks": 2,
		"vision_radius_cells": 3,
	},
	"soldier": {
		"display_name": "Soldier",
		"production_costs": {"wood": 20, "food": 4},
		"production_duration": 15,
		"population_cost": 1,
		"unit_role": "soldier",
		"hp": 30,
		"max_hp": 30,
		"attack_damage": 8,
		"attack_range_cells": 1,
		"attack_cooldown_ticks": 4,
		"vision_radius_cells": 4,
	},
	"archer": {
		"display_name": "Archer",
		"production_costs": {"wood": 15, "stone": 10, "food": 6},
		"production_duration": 20,
		"population_cost": 1,
		"unit_role": "archer",
		"hp": 20,
		"max_hp": 20,
		"attack_damage": 5,
		"attack_range_cells": 3,
		"attack_cooldown_ticks": 5,
		"vision_radius_cells": 5,
	},
	"enemy_dummy": {
		"display_name": "Enemy Unit",
		"production_costs": {},
		"production_duration": 0,
		"population_cost": 0,
		"unit_role": "enemy_dummy",
		"hp": 20,
		"max_hp": 20,
		"attack_damage": 0,
		"attack_range_cells": 0,
		"attack_cooldown_ticks": 0,
		"vision_radius_cells": 4,
	},
}

## Damage multipliers for attacker role vs target role.
## Integer percentages: 100 = 1.0×, 150 = 1.5×. Omitted pairs default to 100.
## Archers counter soldiers (ranged kiting advantage) and have a bonus vs workers.
## Soldiers counter workers (close-quarters crushing) and have a bonus vs archers.
const DAMAGE_MULTIPLIERS: Dictionary = {
	"archer": {
		"soldier": 150,
		"worker": 125,
	},
	"soldier": {
		"worker": 150,
		"archer": 125,
	},
}

## Unit type produced by the stockpile (player base).
const STOCKPILE_PRODUCES: String = "worker"
const BASE_POPULATION_CAP: int = 5
const SPECIAL_STRUCTURES: Dictionary = {
	"stockpile": {
		"display_name": "Base",
		"hp": 60,
		"max_hp": 60,
		"supply_provided": 0,
		"produces": "worker",
		"construction_duration": 0,
		"vision_radius_cells": 4,
	},
	"enemy_base": {
		"display_name": "Enemy Base",
		"hp": 50,
		"max_hp": 50,
		"supply_provided": 0,
		"produces": "",
		"construction_duration": 0,
		"vision_radius_cells": 4,
	},
}
const RESOURCE_NODES: Dictionary = {
	"wood": {
		"display_name": "Wood",
		"default_remaining_amount": 80,
		"is_gatherable": true,
	},
	"stone": {
		"display_name": "Stone",
		"default_remaining_amount": 60,
		"is_gatherable": true,
	},
}


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


static func get_structure_display_name(structure_type: String) -> String:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_string(def, "display_name", structure_type.capitalize())


static func get_structure_construction_duration(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "construction_duration", 0)


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


static func get_structure_produces(structure_type: String) -> String:
	if structure_type == "stockpile":
		return get_stockpile_produces()
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_string(def, "produces", "")


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


static func get_unit_role(unit_type: String) -> String:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_string(def, "unit_role", unit_type)


static func get_unit_attack_range_cells(unit_type: String) -> int:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_int(def, "attack_range_cells", 0)


static func unit_type_can_attack(unit_type: String) -> bool:
	return get_unit_attack_damage(unit_type) > 0


static func get_unit_attack_damage(unit_type: String) -> int:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_int(def, "attack_damage", 0)


static func get_unit_vision_radius(unit_type: String) -> int:
	var def: Dictionary = _get_unit_def(unit_type)
	return _get_int(def, "vision_radius_cells", 0)


static func get_building_vision_radius(building_type: String) -> int:
	var def: Dictionary = _get_structure_def(building_type)
	return _get_int(def, "vision_radius_cells", 0)


## Returns integer damage multiplier (100 = 1.0×) for attacker_role hitting target_role.
## Defaults to 100 when no entry exists (no bonus, no penalty).
static func get_damage_multiplier(attacker_role: String, target_role: String) -> int:
	if not DAMAGE_MULTIPLIERS.has(attacker_role):
		return 100
	var attacker_table: Variant = DAMAGE_MULTIPLIERS[attacker_role]
	if not (attacker_table is Dictionary):
		return 100
	var table: Dictionary = attacker_table
	if not table.has(target_role):
		return 100
	var val: Variant = table[target_role]
	return val if val is int else 100


## Returns a human-readable counter summary for a given attacker role.
## Example: "+50% vs soldiers, +25% vs workers"
## Returns "" when the role has no defined counter bonuses.
static func get_counter_label(attacker_role: String) -> String:
	if not DAMAGE_MULTIPLIERS.has(attacker_role):
		return ""
	var attacker_table: Variant = DAMAGE_MULTIPLIERS[attacker_role]
	if not (attacker_table is Dictionary):
		return ""
	var table: Dictionary = attacker_table
	var roles: Array = table.keys()
	roles.sort()
	var parts: Array[String] = []
	for target_role in roles:
		var val: Variant = table[target_role]
		if val is int and val > 100:
			var bonus: int = val - 100
			var target_display: String = get_unit_display_name(str(target_role)).to_lower() + "s"
			parts.append("+%d%% vs %s" % [bonus, target_display])
	return ", ".join(parts)


static func get_building_supply_provided(building_type: String) -> int:
	var def: Dictionary = _get_building_def(building_type)
	return _get_int(def, "supply_provided", 0)


static func get_structure_supply_provided(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "supply_provided", 0)


static func get_structure_resource_trickle_type(structure_type: String) -> String:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_string(def, "resource_trickle_type", "")


static func get_structure_resource_trickle_amount(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "resource_trickle_amount", 0)


static func get_structure_resource_trickle_interval_ticks(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "resource_trickle_interval_ticks", 0)


static func get_structure_hp(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "hp", 1)


static func get_structure_max_hp(structure_type: String) -> int:
	var def: Dictionary = _get_structure_def(structure_type)
	return _get_int(def, "max_hp", get_structure_hp(structure_type))


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
		"assigned_stockpile_id": producer_id,
	}
	return normalize_entity(entity)


static func create_structure_entity(
	structure_type: String,
	entity_id: int,
	owner_id: int,
	grid_cell: Vector2i,
	is_constructed: bool = true,
	assigned_builder_id: int = 0
) -> Dictionary:
	var structure_entity_type: String = "structure"
	if structure_type == "stockpile":
		structure_entity_type = "stockpile"

	return normalize_entity({
		"id": entity_id,
		"entity_type": structure_entity_type,
		"structure_type": structure_type,
		"owner_id": owner_id,
		"grid_position": grid_cell,
		"is_constructed": is_constructed,
		"construction_progress_ticks": 0 if not is_constructed else get_structure_construction_duration(structure_type),
		"construction_duration_ticks": get_structure_construction_duration(structure_type),
		"assigned_builder_id": assigned_builder_id,
	})


static func create_stockpile_entity(entity_id: int, owner_id: int, grid_cell: Vector2i) -> Dictionary:
	return create_structure_entity("stockpile", entity_id, owner_id, grid_cell, true, 0)


static func create_resource_node_entity(
	resource_type: String,
	entity_id: int,
	grid_cell: Vector2i,
	remaining_amount: int = -1
) -> Dictionary:
	var resource_def: Dictionary = _get_resource_def(resource_type)
	if resource_def.is_empty():
		return {}

	var resolved_amount: int = remaining_amount
	if resolved_amount < 0:
		resolved_amount = _get_int(resource_def, "default_remaining_amount", 0)

	return normalize_entity({
		"id": entity_id,
		"entity_type": "resource_node",
		"resource_type": resource_type,
		"grid_position": grid_cell,
		"remaining_amount": resolved_amount,
	})
	

static func normalize_entity(entity: Dictionary) -> Dictionary:
	if entity.is_empty():
		return {}

	var normalized: Dictionary = entity.duplicate(true)
	var entity_type: String = _get_string(normalized, "entity_type", "")
	if entity_type == "unit":
		return _normalize_unit_entity(normalized)
	if entity_type == "structure" or entity_type == "stockpile":
		return _normalize_structure_entity(normalized)
	if entity_type == "resource_node":
		return _normalize_resource_entity(normalized)
	return normalized


## Compact cost string. Examples: "30W", "25W 20S".
static func format_costs_short(costs: Dictionary) -> String:
	if costs.is_empty():
		return "free"
	var abbreviations: Dictionary = {"food": "F", "stone": "S", "wood": "W"}
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


static func _get_structure_def(structure_type: String) -> Dictionary:
	if SPECIAL_STRUCTURES.has(structure_type):
		var special_value: Variant = SPECIAL_STRUCTURES[structure_type]
		if special_value is Dictionary:
			return special_value
	return _get_building_def(structure_type)


static func _get_resource_def(resource_type: String) -> Dictionary:
	if not RESOURCE_NODES.has(resource_type):
		return {}
	var value: Variant = RESOURCE_NODES[resource_type]
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


static func _normalize_unit_entity(entity: Dictionary) -> Dictionary:
	var unit_type: String = _get_string(entity, "unit_role", "")
	var def: Dictionary = _get_unit_def(unit_type)
	var grid_position: Vector2i = _get_vector2i(entity, "grid_position", Vector2i.ZERO)
	var assigned_stockpile_id: int = _get_int(entity, "assigned_stockpile_id", 0)
	var normalized: Dictionary = {
		"id": _get_int(entity, "id", 0),
		"entity_type": "unit",
		"unit_role": unit_type,
		"owner_id": _get_int(entity, "owner_id", 0),
		"grid_position": grid_position,
		"move_target": _get_vector2i(entity, "move_target", grid_position),
		"path_cells": _get_vector2i_array(entity, "path_cells"),
		"has_move_target": _get_bool(entity, "has_move_target", false),
		"worker_task_state": _get_string(entity, "worker_task_state", "idle"),
		"interaction_slot_cell": _get_vector2i(entity, "interaction_slot_cell", Vector2i(-1, -1)),
		"traffic_state": _get_string(entity, "traffic_state", ""),
		"movement_wait_ticks": _get_int(entity, "movement_wait_ticks", 0),
		"hp": _get_int(entity, "hp", _get_int(def, "hp", 1)),
		"max_hp": _get_int(entity, "max_hp", _get_int(def, "max_hp", 1)),
		"attack_target_id": _get_int(entity, "attack_target_id", 0),
		"attack_cooldown_remaining": _get_int(entity, "attack_cooldown_remaining", 0),
		"attack_damage": _get_int(entity, "attack_damage", _get_int(def, "attack_damage", 0)),
		"attack_range_cells": _get_int(entity, "attack_range_cells", _get_int(def, "attack_range_cells", 0)),
		"attack_cooldown_ticks": _get_int(entity, "attack_cooldown_ticks", _get_int(def, "attack_cooldown_ticks", 0)),
		"attack_move_target_cell": _get_vector2i(entity, "attack_move_target_cell", Vector2i(-1, -1)),
		"population_cost": _get_int(entity, "population_cost", _get_int(def, "population_cost", 0)),
		"assigned_resource_node_id": _get_int(entity, "assigned_resource_node_id", 0),
		"assigned_stockpile_id": assigned_stockpile_id,
		"assigned_construction_site_id": _get_int(entity, "assigned_construction_site_id", 0),
		"carried_resource_type": _get_string(entity, "carried_resource_type", ""),
		"carried_amount": _get_int(entity, "carried_amount", 0),
		"carry_capacity": _get_int(entity, "carry_capacity", _get_int(def, "carry_capacity", 0)),
		"harvest_amount": _get_int(entity, "harvest_amount", _get_int(def, "harvest_amount", 0)),
		"gather_duration_ticks": _get_int(entity, "gather_duration_ticks", _get_int(def, "gather_duration_ticks", 0)),
		"deposit_duration_ticks": _get_int(entity, "deposit_duration_ticks", _get_int(def, "deposit_duration_ticks", 0)),
		"gather_progress_ticks": _get_int(entity, "gather_progress_ticks", 0),
		"vision_radius_cells": _get_int(entity, "vision_radius_cells", _get_int(def, "vision_radius_cells", 0)),
	}
	return normalized


static func _normalize_structure_entity(entity: Dictionary) -> Dictionary:
	var entity_type: String = _get_string(entity, "entity_type", "structure")
	var structure_type: String = _get_string(entity, "structure_type", "")
	if entity_type == "stockpile" and structure_type == "":
		structure_type = "stockpile"
	var def: Dictionary = _get_structure_def(structure_type)
	var is_constructed: bool = _get_bool(entity, "is_constructed", true)
	var construction_duration: int = _get_int(
		entity,
		"construction_duration_ticks",
		_get_int(def, "construction_duration", 0)
	)
	var normalized: Dictionary = {
		"id": _get_int(entity, "id", 0),
		"entity_type": entity_type,
		"structure_type": structure_type,
		"owner_id": _get_int(entity, "owner_id", 0),
		"grid_position": _get_vector2i(entity, "grid_position", Vector2i.ZERO),
		"is_constructed": is_constructed,
		"construction_progress_ticks": _get_int(
			entity,
			"construction_progress_ticks",
			construction_duration if is_constructed else 0
		),
		"construction_duration_ticks": construction_duration,
		"assigned_builder_id": _get_int(entity, "assigned_builder_id", 0),
		"hp": _get_int(entity, "hp", _get_int(def, "hp", 1)),
		"max_hp": _get_int(entity, "max_hp", _get_int(def, "max_hp", 1)),
		"supply_provided": _get_int(entity, "supply_provided", _get_int(def, "supply_provided", 0)),
		"production_queue_count": _get_int(entity, "production_queue_count", 0),
		"production_progress_ticks": _get_int(entity, "production_progress_ticks", 0),
		"production_duration_ticks": _get_int(entity, "production_duration_ticks", 0),
		"produced_unit_type": _get_string(entity, "produced_unit_type", ""),
		"production_blocked": _get_bool(entity, "production_blocked", false),
		"resource_trickle_type": _get_string(
			entity,
			"resource_trickle_type",
			_get_string(def, "resource_trickle_type", "")
		),
		"resource_trickle_amount": _get_int(
			entity,
			"resource_trickle_amount",
			_get_int(def, "resource_trickle_amount", 0)
		),
		"resource_trickle_interval_ticks": _get_int(
			entity,
			"resource_trickle_interval_ticks",
			_get_int(def, "resource_trickle_interval_ticks", 0)
		),
		"resource_trickle_progress_ticks": _get_int(entity, "resource_trickle_progress_ticks", 0),
		"rally_mode": _get_string(entity, "rally_mode", ""),
		"rally_cell": _get_vector2i(entity, "rally_cell", Vector2i(-1, -1)),
		"rally_target_id": _get_int(entity, "rally_target_id", 0),
		"vision_radius_cells": _get_int(entity, "vision_radius_cells", _get_int(def, "vision_radius_cells", 0)),
	}
	if entity_type == "stockpile" and normalized["structure_type"] == "":
		normalized["structure_type"] = "stockpile"
	return normalized


static func _normalize_resource_entity(entity: Dictionary) -> Dictionary:
	var resource_type: String = _get_string(entity, "resource_type", "")
	var def: Dictionary = _get_resource_def(resource_type)
	var remaining_amount: int = _get_int(
		entity,
		"remaining_amount",
		_get_int(def, "default_remaining_amount", 0)
	)
	var is_gatherable: bool = _get_bool(entity, "is_gatherable", _get_bool(def, "is_gatherable", true))
	return {
		"id": _get_int(entity, "id", 0),
		"entity_type": "resource_node",
		"resource_type": resource_type,
		"grid_position": _get_vector2i(entity, "grid_position", Vector2i.ZERO),
		"remaining_amount": remaining_amount,
		"max_amount": _get_int(entity, "max_amount", remaining_amount),
		"is_gatherable": is_gatherable,
		"is_depleted": _get_bool(entity, "is_depleted", remaining_amount <= 0),
	}


static func _get_bool(d: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = d.get(key, fallback)
	if value is bool:
		return value
	return fallback


static func _get_vector2i(d: Dictionary, key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = d.get(key, fallback)
	if value is Vector2i:
		return value
	return fallback


static func _get_vector2i_array(d: Dictionary, key: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not d.has(key):
		return result
	var value: Variant = d[key]
	if not (value is Array):
		return result
	for item in value:
		if item is Vector2i:
			result.append(item)
	return result
