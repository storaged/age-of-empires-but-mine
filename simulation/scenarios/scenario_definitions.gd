class_name ScenarioDefinitions
extends RefCounted

const DEFAULT_SCENARIO_ID: String = "hold_the_valley"

const SCENARIOS: Dictionary = {
	"hold_the_valley": {
		"title": "Hold The Valley",
		"subtitle": "Stabilize, survive first raid, then counterattack.",
		"briefing": "You have room to breathe, but only for a while. Secure food and a barracks before the first raid lands.",
		"map_id": "valley_hold",
		"enemy_plan_id": "steady_pressure",
		"starting_resources": {"food": 0, "wood": 35, "stone": 0},
		"player_layout": {
			"structures": [
				{"structure_type": "stockpile", "cell": Vector2i(2, 2)},
			],
			"units": [
				{"unit_type": "worker", "cell": Vector2i(3, 3)},
				{"unit_type": "worker", "cell": Vector2i(4, 3)},
				{"unit_type": "worker", "cell": Vector2i(3, 4)},
				{"unit_type": "worker", "cell": Vector2i(4, 4)},
			],
		},
		"enemy_layout": {
			"structures": [
				{"structure_type": "enemy_base", "cell": Vector2i(17, 8)},
				{"structure_type": "barracks", "cell": Vector2i(15, 9)},
			],
			"units": [
				{"unit_type": "enemy_dummy", "cell": Vector2i(15, 8)},
			],
		},
		"objectives": [
			{"id": "survive_raid", "text": "Survive until the first raid passes", "condition": {"type": "tick_at_least", "tick": 560}},
			{"id": "destroy_enemy_base", "text": "Destroy the enemy base", "condition": {"type": "destroy_structure_type", "owner_id": 2, "structure_type": "enemy_base"}},
		],
		"victory_condition": {
			"type": "all_conditions",
			"conditions": [
				{"type": "objective_completed", "objective_id": "survive_raid"},
				{"type": "objective_completed", "objective_id": "destroy_enemy_base"},
			],
		},
		"defeat_condition": {"type": "destroy_structure_type", "owner_id": 1, "structure_type": "stockpile"},
		"events": [
			{"id": "briefing_open", "trigger": {"type": "tick_at_least", "tick": 1}, "actions": [{"type": "alert", "kind": "info", "text": "Hold the valley. Farm early and field defenders before the raid."}]},
			{"id": "raid_warning", "trigger": {"type": "tick_at_least", "tick": 420}, "actions": [{"type": "alert", "kind": "warning", "text": "Scout report: first raid approaching."}]},
			{"id": "raid_reinforce", "trigger": {"type": "tick_at_least", "tick": 470}, "actions": [
				{"type": "spawn_units", "owner_id": 2, "unit_type": "enemy_dummy", "cells": [Vector2i(16, 7), Vector2i(17, 7)], "attack_player_base": true},
				{"type": "alert", "kind": "danger", "text": "Enemy raiders enter the valley."},
			]},
			{"id": "raid_survived", "trigger": {"type": "objective_completed", "objective_id": "survive_raid"}, "actions": [{"type": "alert", "kind": "success", "text": "Raid weathered. Counterattack and break the outpost."}]},
		],
	},
	"ridge_breakout": {
		"title": "Ridge Breakout",
		"subtitle": "Expand through the ridge, arm up, and break the outpost.",
		"briefing": "Resources are safer but slower to convert. Build your barracks, train a small force, then push through the ridge gap.",
		"map_id": "split_ridge",
		"enemy_plan_id": "outpost_guard",
		"starting_resources": {"food": 0, "wood": 45, "stone": 5},
		"player_layout": {
			"structures": [
				{"structure_type": "stockpile", "cell": Vector2i(3, 11)},
			],
			"units": [
				{"unit_type": "worker", "cell": Vector2i(4, 11)},
				{"unit_type": "worker", "cell": Vector2i(4, 12)},
				{"unit_type": "worker", "cell": Vector2i(3, 12)},
				{"unit_type": "worker", "cell": Vector2i(5, 11)},
			],
		},
		"enemy_layout": {
			"structures": [
				{"structure_type": "enemy_base", "cell": Vector2i(18, 3)},
				{"structure_type": "barracks", "cell": Vector2i(17, 5)},
			],
			"units": [
				{"unit_type": "enemy_dummy", "cell": Vector2i(18, 5)},
				{"unit_type": "enemy_dummy", "cell": Vector2i(19, 5)},
			],
		},
		"objectives": [
			{"id": "build_barracks", "text": "Construct a barracks", "condition": {"type": "structure_count_at_least", "owner_id": 1, "structure_type": "barracks", "count": 1}},
			{"id": "train_soldiers", "text": "Field 2 soldiers", "condition": {"type": "unit_count_at_least", "owner_id": 1, "unit_role": "soldier", "count": 2}},
			{"id": "destroy_enemy_base", "text": "Destroy the enemy base", "condition": {"type": "destroy_structure_type", "owner_id": 2, "structure_type": "enemy_base"}},
		],
		"victory_condition": {"type": "objective_completed", "objective_id": "destroy_enemy_base"},
		"defeat_condition": {"type": "destroy_structure_type", "owner_id": 1, "structure_type": "stockpile"},
		"events": [
			{"id": "ridge_briefing", "trigger": {"type": "tick_at_least", "tick": 1}, "actions": [{"type": "alert", "kind": "info", "text": "This ridge buys time. Convert it into soldiers before the guard wakes up."}]},
			{"id": "barracks_hint", "trigger": {"type": "objective_completed", "objective_id": "build_barracks"}, "actions": [{"type": "alert", "kind": "success", "text": "Barracks ready. Queue soldiers and prepare the breakout."}]},
			{"id": "guard_warning", "trigger": {"type": "tick_at_least", "tick": 520}, "actions": [{"type": "alert", "kind": "warning", "text": "Enemy patrols are massing beyond the ridge."}]},
		],
	},
	"knife_pass_rush": {
		"title": "Knife Pass Rush",
		"subtitle": "Short map, sharp timings, no wasted steps.",
		"briefing": "The pass is short and pressure comes early. Farm on time, get ranged support, and hold the choke before striking back.",
		"map_id": "knife_pass",
		"enemy_plan_id": "frontier_rush",
		"starting_resources": {"food": 0, "wood": 40, "stone": 0},
		"player_layout": {
			"structures": [
				{"structure_type": "stockpile", "cell": Vector2i(2, 9)},
			],
			"units": [
				{"unit_type": "worker", "cell": Vector2i(3, 9)},
				{"unit_type": "worker", "cell": Vector2i(3, 10)},
				{"unit_type": "worker", "cell": Vector2i(2, 10)},
				{"unit_type": "worker", "cell": Vector2i(4, 9)},
			],
		},
		"enemy_layout": {
			"structures": [
				{"structure_type": "enemy_base", "cell": Vector2i(15, 3)},
				{"structure_type": "archery_range", "cell": Vector2i(14, 4)},
			],
			"units": [
				{"unit_type": "enemy_dummy", "cell": Vector2i(14, 5)},
			],
		},
		"objectives": [
			{"id": "build_farm", "text": "Build a farm", "condition": {"type": "structure_count_at_least", "owner_id": 1, "structure_type": "farm", "count": 1}},
			{"id": "field_ranged", "text": "Field an archer", "condition": {"type": "unit_count_at_least", "owner_id": 1, "unit_role": "archer", "count": 1}},
			{"id": "destroy_enemy_base", "text": "Destroy the enemy base", "condition": {"type": "destroy_structure_type", "owner_id": 2, "structure_type": "enemy_base"}},
		],
		"victory_condition": {"type": "objective_completed", "objective_id": "destroy_enemy_base"},
		"defeat_condition": {"type": "destroy_structure_type", "owner_id": 1, "structure_type": "stockpile"},
		"events": [
			{"id": "pass_briefing", "trigger": {"type": "tick_at_least", "tick": 1}, "actions": [{"type": "alert", "kind": "info", "text": "Knife Pass is short. Farm early or your first archer timing slips."}]},
			{"id": "rush_warning", "trigger": {"type": "tick_at_least", "tick": 260}, "actions": [{"type": "alert", "kind": "danger", "text": "Horn call in the pass. Enemy rush incoming."}]},
			{"id": "rush_spawn", "trigger": {"type": "tick_at_least", "tick": 300}, "actions": [
				{"type": "spawn_units", "owner_id": 2, "unit_type": "enemy_dummy", "cells": [Vector2i(13, 4)], "attack_player_base": true},
			]},
			{"id": "farm_online", "trigger": {"type": "objective_completed", "objective_id": "build_farm"}, "actions": [{"type": "alert", "kind": "success", "text": "Food flow online. Push for ranged support now."}]},
		],
	},
}


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for scenario_id in SCENARIOS.keys():
		if scenario_id is String:
			ids.append(scenario_id)
	ids.sort()
	return ids


static func get_definition(scenario_id: String) -> Dictionary:
	if not SCENARIOS.has(scenario_id):
		return SCENARIOS[DEFAULT_SCENARIO_ID].duplicate(true)
	var scenario_value: Variant = SCENARIOS[scenario_id]
	if scenario_value is Dictionary:
		return scenario_value.duplicate(true)
	return SCENARIOS[DEFAULT_SCENARIO_ID].duplicate(true)


static func get_title(scenario_id: String) -> String:
	var definition: Dictionary = get_definition(scenario_id)
	return str(definition.get("title", scenario_id))
