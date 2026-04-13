class_name EnemyPlanDefinitions
extends RefCounted

const DEFAULT_ENEMY_PLAN_ID: String = "steady_pressure"

const PLANS: Dictionary = {
	"steady_pressure": {
		"display_name": "Steady Pressure",
		"summary": "Slow opening, first real raid after setup.",
		"ai_production_start_tick": 220,
		"ai_production_interval_ticks": 65,
		"ai_attack_start_tick": 520,
		"ai_attack_wave_interval_ticks": 170,
		"ai_min_attackers_per_wave": 2,
	},
	"outpost_guard": {
		"display_name": "Outpost Guard",
		"summary": "Builds slower, attacks in disciplined waves.",
		"ai_production_start_tick": 260,
		"ai_production_interval_ticks": 72,
		"ai_attack_start_tick": 620,
		"ai_attack_wave_interval_ticks": 180,
		"ai_min_attackers_per_wave": 3,
	},
	"frontier_rush": {
		"display_name": "Frontier Rush",
		"summary": "Fast harassment on a short approach map.",
		"ai_production_start_tick": 150,
		"ai_production_interval_ticks": 46,
		"ai_attack_start_tick": 360,
		"ai_attack_wave_interval_ticks": 110,
		"ai_min_attackers_per_wave": 3,
	},
}


static func get_plan(plan_id: String) -> Dictionary:
	if not PLANS.has(plan_id):
		return PLANS[DEFAULT_ENEMY_PLAN_ID].duplicate(true)
	var value: Variant = PLANS[plan_id]
	if value is Dictionary:
		return value.duplicate(true)
	return PLANS[DEFAULT_ENEMY_PLAN_ID].duplicate(true)


static func get_display_name(plan_id: String) -> String:
	var definition: Dictionary = get_plan(plan_id)
	return str(definition.get("display_name", plan_id))
