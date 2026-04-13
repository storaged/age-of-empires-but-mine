class_name AIPresets
extends RefCounted

const DEFAULT_AI_PRESET_ID: String = "standard"

const PRESETS: Dictionary = {
	"relaxed": {
		"display_name": "Relaxed",
		"ai_production_start_tick": 240,
		"ai_production_interval_ticks": 70,
		"ai_attack_start_tick": 560,
		"ai_attack_wave_interval_ticks": 180,
		"ai_min_attackers_per_wave": 2,
	},
	"standard": {
		"display_name": "Standard",
		"ai_production_start_tick": 180,
		"ai_production_interval_ticks": 55,
		"ai_attack_start_tick": 420,
		"ai_attack_wave_interval_ticks": 120,
		"ai_min_attackers_per_wave": 3,
	},
	"rush": {
		"display_name": "Rush",
		"ai_production_start_tick": 120,
		"ai_production_interval_ticks": 40,
		"ai_attack_start_tick": 300,
		"ai_attack_wave_interval_ticks": 90,
		"ai_min_attackers_per_wave": 3,
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
		return PRESETS[DEFAULT_AI_PRESET_ID]
	var preset_value: Variant = PRESETS[preset_id]
	if preset_value is Dictionary:
		return preset_value.duplicate(true)
	return PRESETS[DEFAULT_AI_PRESET_ID].duplicate(true)
